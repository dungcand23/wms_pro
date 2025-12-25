import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../models/document.dart';
import '../storage/local_db.dart';

class SyncService {
  final LocalDb local;
  final Databases db;
  final Realtime realtime;

  final String databaseId;
  final String documentsCol;
  final String ledgerCol;
  final String balancesCol;

  SyncService({
    required this.local,
    required this.db,
    required this.realtime,
    required this.databaseId,
    required this.documentsCol,
    required this.ledgerCol,
    required this.balancesCol,
  });

  /// Push local DRAFT docs lên remote (offline→online)
  Future<void> pushDrafts() async {
    final docs = local.getDocuments().where((d) => d.status == 'DRAFT').toList();
    for (final d in docs) {
      await _upsertDoc(d);
    }
  }

  Future<void> _upsertDoc(Document d) async {
    // id của local dùng luôn làm documentId remote để dễ merge
    final data = d.toJson();
    try {
      await db.getDocument(databaseId: databaseId, collectionId: documentsCol, documentId: d.id);
      await db.updateDocument(
        databaseId: databaseId,
        collectionId: documentsCol,
        documentId: d.id,
        data: data,
      );
    } catch (_) {
      await db.createDocument(
        databaseId: databaseId,
        collectionId: documentsCol,
        documentId: d.id,
        data: data,
      );
    }
  }

  /// Pull documents mới về local (khi multi-user)
  Future<void> pullDocuments({String? updatedAfterIso}) async {
    final queries = <String>[];
    if (updatedAfterIso != null) {
      queries.add(Query.greaterThan('updatedAtIso', updatedAfterIso));
    }
    final res = await db.listDocuments(
      databaseId: databaseId,
      collectionId: documentsCol,
      queries: queries,
    );

    for (final doc in res.documents) {
      final d = Document.fromJson(doc.data);
      await local.docsBox.put(d.id, jsonEncode(d.toJson()));
    }
  }

  /// Realtime: nghe thay đổi ledger/balance để cập nhật local
  dynamic subscribePostedUpdates() {
    final channels = [
      'databases.$databaseId.collections.$ledgerCol.documents',
      'databases.$databaseId.collections.$balancesCol.documents',
    ];

    final sub = realtime.subscribe(channels);

    sub.stream.listen((event) async {
      // TODO Phase4: pull phần thay đổi
    });

    return sub;
  }

}
