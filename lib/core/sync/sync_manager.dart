import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:hive_flutter/hive_flutter.dart';

import '../remote/appwrite_ids.dart';
import '../remote/appwrite_service.dart';
import '../storage/local_db.dart';
import '../models/document.dart';

class SyncManager {
  final LocalDb local;
  final AppwriteService remote;
  final bool isOnline;

  models.RealtimeSubscription? _sub;

  SyncManager({
    required this.local,
    required this.remote,
    required this.isOnline,
  });

  // ===== Outbox for offline drafts =====
  static const _boxName = 'outbox';
  static const _keyDraftIds = 'draft_ids'; // json list of docIds

  Future<void> startRealtime() async {
    if (!isOnline) return;

    _sub ??= remote.realtime.subscribe([
      'databases.${AppwriteIds.databaseId}.collections.${AppwriteIds.colDocs}.documents',
      'databases.${AppwriteIds.databaseId}.collections.${AppwriteIds.colBalances}.documents',
      'databases.${AppwriteIds.databaseId}.collections.${AppwriteIds.colLedger}.documents',
    ]);

    _sub!.stream.listen((event) async {
      // MVP: khi có event -> pull docs mới cập nhật gần đây (an toàn)
      await pullLatestDocuments(limit: 50);
      // balances/ledger: pull theo thời gian gần nhất
      await pullLatestBalances(limit: 300);
      await pullLatestLedger(limit: 500);
    });
  }

  Future<void> stopRealtime() async {
    _sub?.close();
    _sub = null;
  }

  // ====== DRAFT Sync ======
  Future<void> enqueueDraft(String docId) async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_keyDraftIds);
    final ids = raw == null ? <String>[] : (jsonDecode(raw) as List).cast<String>();
    if (!ids.contains(docId)) ids.add(docId);
    await box.put(_keyDraftIds, jsonEncode(ids));
  }

  Future<void> pushDrafts() async {
    if (!isOnline) return;
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_keyDraftIds);
    final ids = raw == null ? <String>[] : (jsonDecode(raw) as List).cast<String>();
    if (ids.isEmpty) return;

    final remain = <String>[];

    for (final id in ids) {
      final doc = local.getDocument(id);
      if (doc == null) continue;
      // chỉ push DRAFT
      if (doc.status != 'DRAFT') continue;

      try {
        await _upsertRemoteDoc(doc);
      } catch (_) {
        remain.add(id);
      }
    }

    await box.put(_keyDraftIds, jsonEncode(remain));
  }

  Future<void> _upsertRemoteDoc(Document doc) async {
    final data = doc.toJson();

    try {
      await remote.db.getDocument(
        databaseId: AppwriteIds.databaseId,
        collectionId: AppwriteIds.colDocs,
        documentId: doc.id,
      );

      await remote.db.updateDocument(
        databaseId: AppwriteIds.databaseId,
        collectionId: AppwriteIds.colDocs,
        documentId: doc.id,
        data: data,
      );
    } catch (_) {
      await remote.db.createDocument(
        databaseId: AppwriteIds.databaseId,
        collectionId: AppwriteIds.colDocs,
        documentId: doc.id,
        data: data,
      );
    }
  }

  // ===== Pull latest =====
  Future<void> pullLatestDocuments({int limit = 50}) async {
    if (!isOnline) return;

    final res = await remote.db.listDocuments(
      databaseId: AppwriteIds.databaseId,
      collectionId: AppwriteIds.colDocs,
      queries: [
        Query.orderDesc('updatedAtIso'),
        Query.limit(limit),
      ],
    );

    for (final d in res.documents) {
      final doc = Document.fromJson(d.data);
      await local.docsBox.put(doc.id, jsonEncode(doc.toJson()));
    }
  }

  Future<void> pullLatestBalances({int limit = 300}) async {
    if (!isOnline) return;

    final res = await remote.db.listDocuments(
      databaseId: AppwriteIds.databaseId,
      collectionId: AppwriteIds.colBalances,
      queries: [
        Query.orderDesc('updatedAtIso'),
        Query.limit(limit),
      ],
    );

    for (final b in res.documents) {
      // balanceBox key chính là b.data['key']
      final key = b.data['key'] as String;
      await local.balanceBox.put(key, jsonEncode(b.data));
    }
  }

  Future<void> pullLatestLedger({int limit = 500}) async {
    if (!isOnline) return;

    final res = await remote.db.listDocuments(
      databaseId: AppwriteIds.databaseId,
      collectionId: AppwriteIds.colLedger,
      queries: [
        Query.orderDesc('tsIso'),
        Query.limit(limit),
      ],
    );

    for (final l in res.documents) {
      final id = l.data['id'] as String? ?? l.$id; // tùy schema
      await local.ledgerBox.put(id, jsonEncode(l.data));
    }
  }

  // ===== Online-only workflow: submit/approve/post =====
  Future<void> submitOnline(String docId) async {
    if (!isOnline) throw Exception('SUBMIT requires online');
    // client đổi trạng thái local + upsert remote
    final doc = local.getDocument(docId);
    if (doc == null) throw Exception('Doc not found');
    final updated = doc.copyWith(status: 'SUBMITTED', updatedAtIso: DateTime.now().toIso8601String());
    await local.docsBox.put(docId, jsonEncode(updated.toJson()));
    await _upsertRemoteDoc(updated);
  }

  Future<void> approveOnline(String docId) async {
    if (!isOnline) throw Exception('APPROVE requires online');
    final doc = local.getDocument(docId);
    if (doc == null) throw Exception('Doc not found');
    final updated = doc.copyWith(status: 'APPROVED', updatedAtIso: DateTime.now().toIso8601String());
    await local.docsBox.put(docId, jsonEncode(updated.toJson()));
    await _upsertRemoteDoc(updated);
  }

  /// ✅ POST qua Appwrite Function => server validate + idempotent + ledger+balances
  Future<void> postOnline(String docId) async {
    if (!isOnline) throw Exception('POST requires online');

    final exec = await remote.functions.createExecution(
      functionId: AppwriteIds.fnPost,
      body: jsonEncode({'docId': docId}),
    );

    if (exec.status != 'completed') {
      throw Exception('POST failed: ${exec.status}');
    }

    // Pull lại ngay để local sync chuẩn
    await pullLatestDocuments(limit: 30);
    await pullLatestBalances(limit: 500);
    await pullLatestLedger(limit: 800);
  }
}
