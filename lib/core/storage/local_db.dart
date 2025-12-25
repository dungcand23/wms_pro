// lib/core/storage/local_db.dart
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/audit.dart';
import '../models/attachment.dart';
import '../models/document.dart';
import '../models/ledger_balance.dart';
import '../models/location_node.dart';
import '../models/lot.dart';
import '../models/sku.dart';
import '../models/uom.dart';
import '../models/user.dart';

class LocalDb {
  // ✅ Boxes (Hive)
  final Box<String> skusBox;
  final Box<String> uomsBox;
  final Box<String> locationsBox;
  final Box<String> lotsBox;

  final Box<String> docsBox;
  final Box<String> ledgerBox;
  final Box<String> balanceBox;

  final Box<String> countersBox;
  final Box<String> postLogBox;
  final Box<String> reasonsBox;

  // Phase 3 extras
  final Box<String> auditBox;
  final Box<String> attachmentsBox;

  final _uuid = const Uuid();

  LocalDb._({
    required this.skusBox,
    required this.uomsBox,
    required this.locationsBox,
    required this.lotsBox,
    required this.docsBox,
    required this.ledgerBox,
    required this.balanceBox,
    required this.countersBox,
    required this.postLogBox,
    required this.reasonsBox,
    required this.auditBox,
    required this.attachmentsBox,
  });

  static Future<LocalDb> open() async {
    final skus = await Hive.openBox<String>('skus');
    final uoms = await Hive.openBox<String>('uoms');
    final locs = await Hive.openBox<String>('locations');
    final lots = await Hive.openBox<String>('lots');

    final docs = await Hive.openBox<String>('documents');
    final ledger = await Hive.openBox<String>('ledger');
    final balances = await Hive.openBox<String>('balances');

    final counters = await Hive.openBox<String>('counters');
    final postlog = await Hive.openBox<String>('postlog');
    final reasons = await Hive.openBox<String>('reasons');

    final audits = await Hive.openBox<String>('audits');
    final attachments = await Hive.openBox<String>('attachments');

    final db = LocalDb._(
      skusBox: skus,
      uomsBox: uoms,
      locationsBox: locs,
      lotsBox: lots,
      docsBox: docs,
      ledgerBox: ledger,
      balanceBox: balances,
      countersBox: counters,
      postLogBox: postlog,
      reasonsBox: reasons,
      auditBox: audits,
      attachmentsBox: attachments,
    );

    await db._seedIfEmpty();
    return db;
  }

  // ============================================================
  // Keys / helpers
  // ============================================================

  /// Multi-tenant future: prefix = tenantId. MVP single-tenant uses "default".
  String balanceKey({
    String tenantId = 'default',
    required String locationId,
    required String skuId,
    required String lotId,
    required String status,
  }) =>
      '$tenantId|$locationId|$skuId|$lotId|$status';

  double _round3(double v) => double.parse(v.toStringAsFixed(3));

  // ============================================================
  // Seed (demo data)
  // ============================================================

  Future<void> _seedIfEmpty() async {
    if (skusBox.isNotEmpty) return;

    // Reason codes (Phase 3)
    for (final r in ['COUNT', 'DAMAGE', 'RETURN', 'HOLD_MOVE', 'CANCEL']) {
      reasonsBox.put(r, r);
    }

    // 1 SKU demo
    final sku1 = Sku(
      id: _uuid.v4(),
      code: 'ACME1001',
      name: 'ACME Bolt 10mm',
      baseType: 'EA', // EA = integer base
      baseUom: 'PCS',
    );
    skusBox.put(sku1.id, jsonEncode(sku1.toJson()));
    _putUom(SkuUom(skuId: sku1.id, uom: 'PCS', factorToBase: 1, isBase: true));
    _putUom(SkuUom(skuId: sku1.id, uom: 'BOX', factorToBase: 100, isBase: false));

    // 2 location demo
    final locA = LocationNode(
      id: _uuid.v4(),
      warehouseCode: 'VN_HCM01',
      code: 'KH01-A01',
      type: 'PICK',
    );
    final locB = LocationNode(
      id: _uuid.v4(),
      warehouseCode: 'VN_HCM01',
      code: 'KH01-B01',
      type: 'STORAGE',
    );
    locationsBox.put(locA.id, jsonEncode(locA.toJson()));
    locationsBox.put(locB.id, jsonEncode(locB.toJson()));

    // 2 lot demo (FEFO: lot2 expiry sớm hơn)
    final lot1 = Lot(
      id: _uuid.v4(),
      skuId: sku1.id,
      lotCode: 'BATCH202301',
      expiryIso: '2026-02-10',
    );
    final lot2 = Lot(
      id: _uuid.v4(),
      skuId: sku1.id,
      lotCode: 'BATCH202212',
      expiryIso: '2025-12-05',
    );
    lotsBox.put(lot1.id, jsonEncode(lot1.toJson()));
    lotsBox.put(lot2.id, jsonEncode(lot2.toJson()));

    // Balances demo
    await _setBalance(locationId: locA.id, skuId: sku1.id, lotId: lot1.id, status: 'AVAILABLE', qtyBase: 35);
    await _setBalance(locationId: locA.id, skuId: sku1.id, lotId: lot2.id, status: 'AVAILABLE', qtyBase: 25);
    await _setBalance(locationId: locA.id, skuId: sku1.id, lotId: lot2.id, status: 'HOLD', qtyBase: 5);
  }

  void _putUom(SkuUom uom) {
    final key = '${uom.skuId}|${uom.uom}';
    uomsBox.put(key, jsonEncode(uom.toJson()));
  }

  Future<void> _setBalance({
    required String locationId,
    required String skuId,
    required String lotId,
    required String status,
    required double qtyBase,
  }) async {
    final key = balanceKey(locationId: locationId, skuId: skuId, lotId: lotId, status: status);
    final row = BalanceRow(
      key: key,
      locationId: locationId,
      skuId: skuId,
      lotId: lotId,
      status: status,
      qtyBase: qtyBase,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    await balanceBox.put(key, jsonEncode(row.toJson()));
  }

  // ============================================================
  // READ APIs
  // ============================================================

  List<Sku> getSkus() {
    final res = skusBox.values.map((s) => Sku.fromJson(jsonDecode(s))).toList();
    res.sort((a, b) => a.code.compareTo(b.code));
    return res;
  }

  List<LocationNode> getLocations({String? warehouseCode}) {
    final all = locationsBox.values
        .map((s) => LocationNode.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    if (warehouseCode == null) return all;
    return all.where((e) => e.warehouseCode == warehouseCode).toList();
  }

  List<Lot> getLots({String? skuId}) {
    final all = lotsBox.values.map((s) => Lot.fromJson(jsonDecode(s))).toList();
    if (skuId == null) return all;
    return all.where((e) => e.skuId == skuId).toList();
  }

  List<SkuUom> getUoms(String skuId) {
    final res = <SkuUom>[];
    for (final v in uomsBox.values) {
      final u = SkuUom.fromJson(jsonDecode(v));
      if (u.skuId == skuId) res.add(u);
    }
    // base first
    res.sort((a, b) => (b.isBase ? 1 : 0) - (a.isBase ? 1 : 0));
    return res;
  }

  SkuUom? findUom(String skuId, String uom) {
    final key = '$skuId|$uom';
    final v = uomsBox.get(key);
    if (v == null) return null;
    return SkuUom.fromJson(jsonDecode(v));
  }

  List<String> getReasonCodes() => reasonsBox.values.cast<String>().toList();

  List<Document> getDocuments() {
    final res = docsBox.values.map((s) => Document.fromJson(jsonDecode(s))).toList();
    res.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
    return res;
  }

  Document? getDocument(String id) {
    final s = docsBox.get(id);
    if (s == null) return null;
    return Document.fromJson(jsonDecode(s));
  }

  List<BalanceRow> getBalances() =>
      balanceBox.values.map((s) => BalanceRow.fromJson(jsonDecode(s))).toList();

  List<LedgerEntry> getLedger() {
    final res = ledgerBox.values.map((s) => LedgerEntry.fromJson(jsonDecode(s))).toList();
    res.sort((a, b) => b.tsIso.compareTo(a.tsIso));
    return res;
  }

  // Streams for UI refresh
  Stream<void> watchDocs() => docsBox.watch().map((_) {});
  Stream<void> watchBalances() => balanceBox.watch().map((_) {});

  // ============================================================
  // AUDIT (Phase 3 B-level)
  // ============================================================

  Future<void> _audit({
    required AppUser actor,
    required String entityType, // DOC/SKU/UOM/LOC...
    required String entityId,
    required String action, // CREATE/UPDATE/STATUS/POST/CANCEL/REVERSE/ATTACH
    required List<String> changedFields,
    String? reason,
    Map<String, dynamic>? beforeJson,
    Map<String, dynamic>? afterJson,
  }) async {
    final entry = AuditEntry(
      id: _uuid.v4(),
      tsIso: DateTime.now().toIso8601String(),
      actor: '${actor.id}:${actor.role}',
      entityType: entityType,
      entityId: entityId,
      action: action,
      reason: reason,
      changedFields: changedFields,
      beforeJson: beforeJson,
      afterJson: afterJson,
    );
    await auditBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  // ============================================================
  // UOM conversion + number rules
  // ============================================================

  /// qty_base = qty_input * factorToBase
  /// Rule:
  /// - baseType EA => integer only
  /// - baseType KG/L => 3 decimals
  double convertToBaseOrThrow(Sku sku, String uom, double qtyInput) {
    final conv = findUom(sku.id, uom);
    if (conv == null) throw Exception('UOM not configured: $uom for SKU ${sku.code}');
    final base = qtyInput * conv.factorToBase;

    if (sku.baseType == 'EA') {
      if (base % 1 != 0) throw Exception('SKU ${sku.code} requires integer base qty');
      return base;
    }
    return _round3(base);
  }

  // ============================================================
  // Attachments (Phase 3: metadata only)
  // ============================================================

  Future<List<AttachmentRef>> getAttachmentsForDoc(String docId) async {
    final res = <AttachmentRef>[];
    for (final v in attachmentsBox.values) {
      final a = AttachmentRef.fromJson(jsonDecode(v));
      if (a.docId == docId) res.add(a);
    }
    res.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
    return res;
  }

  Future<AttachmentRef> addAttachmentMeta({
    required AppUser actor,
    required String docId,
    required String fileName,
    required String mime,
    required int sizeBytes,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    final a = AttachmentRef(
      id: id,
      docId: docId,
      fileName: fileName,
      mime: mime,
      sizeBytes: sizeBytes,
      note: note,
      createdAtIso: now,
      createdBy: actor.id,
    );

    attachmentsBox.put(id, jsonEncode(a.toJson()));

    final doc = getDocument(docId);
    if (doc != null) {
      final updated = doc.copyWith(
        updatedAtIso: now,
        attachmentIds: [...doc.attachmentIds, id],
      );
      await docsBox.put(updated.id, jsonEncode(updated.toJson()));
      await _audit(
        actor: actor,
        entityType: 'DOC',
        entityId: docId,
        action: 'ATTACH',
        changedFields: const ['attachmentIds'],
        beforeJson: doc.toJson(),
        afterJson: updated.toJson(),
      );
    }
    return a;
  }

  // ============================================================
  // Backup / Export all (Phase 3)
  // ============================================================

  Future<String> exportAllJson({DateTime? from, DateTime? to}) async {
    bool inRange(String iso) {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return true;
      if (from != null && dt.isBefore(from)) return false;
      if (to != null && dt.isAfter(to)) return false;
      return true;
    }

    final map = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'skus': skusBox.values.map((e) => jsonDecode(e)).toList(),
      'uoms': uomsBox.values.map((e) => jsonDecode(e)).toList(),
      'locations': locationsBox.values.map((e) => jsonDecode(e)).toList(),
      'lots': lotsBox.values.map((e) => jsonDecode(e)).toList(),
      'documents': docsBox.values.map((e) => jsonDecode(e)).toList(),
      'balances': balanceBox.values.map((e) => jsonDecode(e)).toList(),
      'ledger': ledgerBox.values.map((e) => jsonDecode(e)).where((j) => inRange(j['tsIso'] ?? '')).toList(),
      'audits': auditBox.values.map((e) => jsonDecode(e)).where((j) => inRange(j['tsIso'] ?? '')).toList(),
      'attachments': attachmentsBox.values.map((e) => jsonDecode(e)).toList(),
      'counters': countersBox.toMap(),
      'postlog': postLogBox.toMap(),
      'reasons': reasonsBox.toMap(),
    };

    return const JsonEncoder.withIndent('  ').convert(map);
  }

  // ============================================================
  // Documents CRUD + Workflow
  // ============================================================

  Future<Document> createNewDocument({
    required AppUser actor,
    required String docType,
    required String warehouseCode,
  }) async {
    final now = DateTime.now().toIso8601String();
    final docNo = await _nextDocNo(docType);

    final doc = Document(
      id: _uuid.v4(),
      docType: docType, // IN/OUT/TRF/ADJ/REV/STATUS_MOVE
      docNo: docNo,
      status: 'DRAFT',
      warehouseCode: warehouseCode,
      createdAtIso: now,
      updatedAtIso: now,
      createdBy: actor.id,
      lines: const [],
      attachmentIds: const [],
    );

    await saveDocument(actor, doc, auditAction: 'CREATE');
    return doc;
  }

  Future<void> saveDocument(AppUser actor, Document doc, {String auditAction = 'UPDATE'}) async {
    await docsBox.put(doc.id, jsonEncode(doc.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: doc.id,
      action: auditAction,
      changedFields: const ['*'],
      afterJson: doc.toJson(),
    );
  }

  Future<void> setDocNote(AppUser actor, String docId, String? note) async {
    final doc = getDocument(docId);
    if (doc == null) return;
    final before = doc.toJson();
    final updated = doc.copyWith(
      updatedAtIso: DateTime.now().toIso8601String(),
      note: note,
    );
    await docsBox.put(updated.id, jsonEncode(updated.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: docId,
      action: 'UPDATE',
      changedFields: const ['note'],
      beforeJson: before,
      afterJson: updated.toJson(),
    );
  }

  Future<void> addLine(AppUser actor, String docId, DocumentLine line) async {
    final doc = getDocument(docId);
    if (doc == null) return;
    if (doc.status != 'DRAFT') throw Exception('Only DRAFT can edit lines');

    // Basic guard
    if (line.qtyBase == 0) throw Exception('qty_base cannot be 0');

    final updated = doc.copyWith(
      updatedAtIso: DateTime.now().toIso8601String(),
      lines: [...doc.lines, line],
    );

    await docsBox.put(updated.id, jsonEncode(updated.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: docId,
      action: 'UPDATE',
      changedFields: const ['lines'],
      beforeJson: doc.toJson(),
      afterJson: updated.toJson(),
    );
  }

  Future<void> removeLine(AppUser actor, String docId, String lineId) async {
    final doc = getDocument(docId);
    if (doc == null) return;
    if (doc.status != 'DRAFT') throw Exception('Only DRAFT can edit lines');

    final updated = doc.copyWith(
      updatedAtIso: DateTime.now().toIso8601String(),
      lines: doc.lines.where((e) => e.id != lineId).toList(),
    );

    await docsBox.put(updated.id, jsonEncode(updated.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: docId,
      action: 'UPDATE',
      changedFields: const ['lines'],
      beforeJson: doc.toJson(),
      afterJson: updated.toJson(),
    );
  }

  // ------------------ Workflow ------------------

  Future<void> submit(AppUser actor, String docId) async {
    final doc = getDocument(docId);
    if (doc == null) return;
    if (doc.status != 'DRAFT') throw Exception('Only DRAFT can submit');
    if (doc.docType != 'REV' && doc.lines.isEmpty) throw Exception('No lines');
    await _setStatus(actor, doc, 'SUBMITTED');
  }

  Future<void> approve(AppUser actor, String docId) async {
    final doc = getDocument(docId);
    if (doc == null) return;
    if (!actor.canApprove) throw Exception('No permission to approve');
    if (doc.status != 'SUBMITTED') throw Exception('Only SUBMITTED can approve');
    await _setStatus(actor, doc, 'APPROVED');
  }

  /// Cancel only before POSTED
  Future<void> cancel(AppUser actor, String docId, {String? reasonCode}) async {
    final doc = getDocument(docId);
    if (doc == null) return;

    if (doc.status == 'POSTED') throw Exception('Cannot cancel POSTED');
    if (doc.status == 'CANCELLED') return;

    final before = doc.toJson();
    final updated = doc.copyWith(
      status: 'CANCELLED',
      updatedAtIso: DateTime.now().toIso8601String(),
      reasonCode: reasonCode ?? doc.reasonCode ?? 'CANCEL',
    );

    await docsBox.put(updated.id, jsonEncode(updated.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: docId,
      action: 'CANCEL',
      reason: updated.reasonCode,
      changedFields: const ['status', 'reasonCode'],
      beforeJson: before,
      afterJson: updated.toJson(),
    );
  }

  /// Create REV doc referencing source POSTED doc
  Future<Document> createReverseDoc(
      AppUser actor,
      String sourceDocId, {
        required String reasonCode,
      }) async {
    final src = getDocument(sourceDocId);
    if (src == null) throw Exception('Source doc not found');
    if (src.status != 'POSTED') throw Exception('Only POSTED can be reversed');

    final now = DateTime.now().toIso8601String();
    final docNo = await _nextDocNo('REV');

    final rev = Document(
      id: _uuid.v4(),
      docType: 'REV',
      docNo: docNo,
      status: 'DRAFT',
      warehouseCode: src.warehouseCode,
      createdAtIso: now,
      updatedAtIso: now,
      createdBy: actor.id,
      refDocId: src.id,
      reasonCode: reasonCode,
      note: null,
      lines: const [],
      attachmentIds: const [],
    );

    await saveDocument(actor, rev, auditAction: 'CREATE');
    return rev;
  }

  // ============================================================
  // POST engine (ledger append-only + balance cached + idempotent)
  // ============================================================

  Future<void> post(AppUser actor, String docId) async {
    final doc = getDocument(docId);
    if (doc == null) throw Exception('Doc not found');
    if (!actor.canPost) throw Exception('No permission to post');
    if (doc.status != 'APPROVED') throw Exception('Only APPROVED can be POSTED');

    // ✅ idempotent (post twice => no double ledger)
    if (postLogBox.containsKey(docId)) return;

    if (doc.docType == 'REV') {
      await _postReverse(actor, doc);
      await postLogBox.put(docId, DateTime.now().toIso8601String());
      await _setStatus(actor, doc, 'POSTED');

      // mark source as REVERSED
      final src = getDocument(doc.refDocId!);
      if (src != null && src.status == 'POSTED') {
        final src2 = src.copyWith(
          status: 'REVERSED',
          updatedAtIso: DateTime.now().toIso8601String(),
        );
        await docsBox.put(src2.id, jsonEncode(src2.toJson()));
      }
      return;
    }

    if (doc.lines.isEmpty) throw Exception('No lines');

    // Stage
    final deltas = <_Delta>[];
    final ledgers = <_LedgerWrite>[];

    for (final line in doc.lines) {
      await _stageLineOrThrow(actor, doc, line, deltas, ledgers);
    }

    // Atomic apply (validate no negative)
    await _applyBatchOrThrow(actor, doc, deltas, ledgers);

    await postLogBox.put(docId, DateTime.now().toIso8601String());
    await _setStatus(actor, doc, 'POSTED');
  }

  Future<void> _setStatus(AppUser actor, Document doc, String status) async {
    final before = doc.toJson();
    final updated = doc.copyWith(
      status: status,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    await docsBox.put(updated.id, jsonEncode(updated.toJson()));
    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: doc.id,
      action: 'STATUS',
      changedFields: const ['status'],
      beforeJson: before,
      afterJson: updated.toJson(),
    );
  }

  // ------------------ Stage line ------------------

  Future<void> _stageLineOrThrow(
      AppUser actor,
      Document doc,
      DocumentLine line,
      List<_Delta> deltas,
      List<_LedgerWrite> ledgers,
      ) async {
    // Guards by docType
    if (doc.docType == 'IN' || doc.docType == 'OUT' || doc.docType == 'TRF' || doc.docType == 'STATUS_MOVE') {
      if (line.qtyBase <= 0) throw Exception('${doc.docType} requires qty_base > 0');
    }
    if (doc.docType == 'ADJ') {
      if (line.qtyBase == 0) throw Exception('ADJ qty_base cannot be 0');
    }

    // Lot
    final lotId = line.lotId ?? _ensureNoLot(line.skuId);

    // validate lot
    final lot = getLots(skuId: line.skuId).firstWhere((l) => l.id == lotId);
    if (lot.blocked) throw Exception('Lot is blocked');

    // expiry rule: expired -> supervisor only
    final today = DateTime.now();
    final day0 = DateTime(today.year, today.month, today.day);
    final exp = lot.expiry;
    if (exp != null && exp.isBefore(day0) && !actor.isSupervisor) {
      throw Exception('Lot expired. Supervisor override required.');
    }

    // Routing by docType
    if (doc.docType == 'IN') {
      final toLoc = line.toLocationId;
      if (toLoc == null) throw Exception('IN requires toLocation');
      _addDelta(deltas, toLoc, line.skuId, lotId, line.status, line.qtyBase);
      _addLedger(ledgers, line, toLoc, line.skuId, lotId, line.status, line.qtyBase);
      return;
    }

    if (doc.docType == 'OUT') {
      final fromLoc = line.fromLocationId;
      if (fromLoc == null) throw Exception('OUT requires fromLocation');
      if (line.status != 'AVAILABLE') throw Exception('OUT only uses AVAILABLE');

      // FEFO by default if lotId == null
      if (line.lotId == null) {
        final alloc = _fefoAllocateOrThrow(
          actor: actor,
          fromLocId: fromLoc,
          skuId: line.skuId,
          qtyNeed: line.qtyBase,
        );
        for (final a in alloc) {
          _addDelta(deltas, fromLoc, line.skuId, a.lotId, 'AVAILABLE', -a.qty);
          _addLedger(ledgers, line, fromLoc, line.skuId, a.lotId, 'AVAILABLE', -a.qty);
        }
        return;
      }

      // manual lot pick = supervisor only
      if (!actor.isSupervisor) throw Exception('Supervisor required to pick lot manually');
      _addDelta(deltas, fromLoc, line.skuId, lotId, 'AVAILABLE', -line.qtyBase);
      _addLedger(ledgers, line, fromLoc, line.skuId, lotId, 'AVAILABLE', -line.qtyBase);
      return;
    }

    if (doc.docType == 'TRF') {
      final fromLoc = line.fromLocationId;
      final toLoc = line.toLocationId;
      if (fromLoc == null || toLoc == null) throw Exception('TRF requires from/to');
      if (line.status != 'AVAILABLE') throw Exception('TRF only uses AVAILABLE');

      _addDelta(deltas, fromLoc, line.skuId, lotId, 'AVAILABLE', -line.qtyBase);
      _addDelta(deltas, toLoc, line.skuId, lotId, 'AVAILABLE', line.qtyBase);

      _addLedger(ledgers, line, fromLoc, line.skuId, lotId, 'AVAILABLE', -line.qtyBase);
      _addLedger(ledgers, line, toLoc, line.skuId, lotId, 'AVAILABLE', line.qtyBase);
      return;
    }

    if (doc.docType == 'ADJ') {
      if (line.reasonCode == null || line.reasonCode!.isEmpty) {
        throw Exception('ADJ requires reasonCode');
      }
      final loc = line.fromLocationId ?? line.toLocationId;
      if (loc == null) throw Exception('ADJ requires location');

      // qtyBase may be +/- (delta)
      _addDelta(deltas, loc, line.skuId, lotId, line.status, line.qtyBase);
      _addLedger(ledgers, line, loc, line.skuId, lotId, line.status, line.qtyBase);
      return;
    }

    if (doc.docType == 'STATUS_MOVE') {
      if (line.toStatus == null) throw Exception('STATUS_MOVE requires toStatus');
      if (line.reasonCode == null || line.reasonCode!.isEmpty) {
        throw Exception('STATUS_MOVE requires reasonCode');
      }
      final loc = line.fromLocationId ?? line.toLocationId;
      if (loc == null) throw Exception('STATUS_MOVE requires location');

      _addDelta(deltas, loc, line.skuId, lotId, line.status, -line.qtyBase);
      _addDelta(deltas, loc, line.skuId, lotId, line.toStatus!, line.qtyBase);

      _addLedger(ledgers, line, loc, line.skuId, lotId, line.status, -line.qtyBase);
      _addLedger(ledgers, line, loc, line.skuId, lotId, line.toStatus!, line.qtyBase);
      return;
    }

    throw Exception('Unsupported docType: ${doc.docType}');
  }

  // ------------------ FEFO allocate ------------------

  List<_Alloc> _fefoAllocateOrThrow({
    required AppUser actor,
    required String fromLocId,
    required String skuId,
    required double qtyNeed,
  }) {
    final lots = getLots(skuId: skuId)
      ..removeWhere((l) => l.blocked)
      ..sort((a, b) {
        final ae = a.expiry ?? DateTime(2999);
        final be = b.expiry ?? DateTime(2999);
        return ae.compareTo(be);
      });

    final today = DateTime.now();
    final day0 = DateTime(today.year, today.month, today.day);

    final snap = _snapshotBalances();

    double remain = qtyNeed;
    final alloc = <_Alloc>[];

    for (final lot in lots) {
      if (remain <= 0) break;

      // expired lot: skip unless supervisor
      if (lot.expiry != null && lot.expiry!.isBefore(day0) && !actor.isSupervisor) {
        continue;
      }

      final key = balanceKey(locationId: fromLocId, skuId: skuId, lotId: lot.id, status: 'AVAILABLE');
      final cur = snap[key] ?? 0;
      if (cur <= 0) continue;

      final take = cur >= remain ? remain : cur;
      alloc.add(_Alloc(lotId: lot.id, qty: take));
      remain -= take;
    }

    if (remain > 0) {
      throw Exception('Insufficient stock (FEFO). Remaining: $remain');
    }
    return alloc;
  }

  // ------------------ Atomic apply ------------------

  Map<String, double> _snapshotBalances() {
    final m = <String, double>{};
    for (final v in balanceBox.values) {
      final row = BalanceRow.fromJson(jsonDecode(v));
      m[row.key] = (row.qtyBase as num).toDouble();
    }
    return m;
  }

  Future<void> _applyBatchOrThrow(
      AppUser actor,
      Document doc,
      List<_Delta> deltas,
      List<_LedgerWrite> ledgers,
      ) async {
    final snap = _snapshotBalances();

    // 1) Validate no-negative
    for (final d in deltas) {
      final key = balanceKey(locationId: d.locationId, skuId: d.skuId, lotId: d.lotId, status: d.status);
      final cur = snap[key] ?? 0;
      final next = cur + d.delta;
      if (next < 0) {
        throw Exception('Negative inventory not allowed (key=$key, have=$cur, delta=${d.delta})');
      }
      snap[key] = next;
    }

    // 2) Append ledger
    final nowIso = DateTime.now().toIso8601String();
    for (final w in ledgers) {
      final le = LedgerEntry(
        id: _uuid.v4(),
        tsIso: nowIso,
        docId: doc.id,
        docNo: doc.docNo,
        docType: doc.docType,
        lineId: w.lineId,
        locationId: w.locationId,
        skuId: w.skuId,
        lotId: w.lotId,
        status: w.status,
        qtyDeltaBase: w.delta,
      );
      await ledgerBox.put(le.id, jsonEncode(le.toJson()));
    }

    // 3) Update balances
    for (final d in deltas) {
      final key = balanceKey(locationId: d.locationId, skuId: d.skuId, lotId: d.lotId, status: d.status);
      final qty = snap[key] ?? 0;
      final row = BalanceRow(
        key: key,
        locationId: d.locationId,
        skuId: d.skuId,
        lotId: d.lotId,
        status: d.status,
        qtyBase: qty,
        updatedAtIso: nowIso,
      );
      await balanceBox.put(key, jsonEncode(row.toJson()));
    }

    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: doc.id,
      action: 'POST',
      changedFields: const ['ledger', 'balance', 'status'],
      afterJson: doc.toJson(),
    );
  }

  // ------------------ Reverse posting ------------------

  Future<void> _postReverse(AppUser actor, Document revDoc) async {
    if (revDoc.refDocId == null) throw Exception('REV requires refDocId');
    if (revDoc.reasonCode == null || revDoc.reasonCode!.isEmpty) {
      throw Exception('REV requires reasonCode');
    }

    final src = getDocument(revDoc.refDocId!);
    if (src == null) throw Exception('Ref doc not found');
    if (src.status != 'POSTED') throw Exception('Ref doc must be POSTED');

    final srcLedgers = getLedger().where((e) => e.docId == src.id).toList();
    if (srcLedgers.isEmpty) throw Exception('No ledger to reverse');

    final deltas = <_Delta>[];
    final ledgers = <_LedgerWrite>[];

    for (final le in srcLedgers) {
      final inv = -((le.qtyDeltaBase as num).toDouble());
      _addDelta(deltas, le.locationId, le.skuId, le.lotId, le.status, inv);
      ledgers.add(_LedgerWrite(
        lineId: le.lineId,
        locationId: le.locationId,
        skuId: le.skuId,
        lotId: le.lotId,
        status: le.status,
        delta: inv,
      ));
    }

    await _applyBatchOrThrow(actor, revDoc, deltas, ledgers);

    await _audit(
      actor: actor,
      entityType: 'DOC',
      entityId: revDoc.id,
      action: 'REVERSE',
      reason: revDoc.reasonCode,
      changedFields: const ['ledger', 'balance'],
      afterJson: revDoc.toJson(),
    );
  }

  // ============================================================
  // Internals
  // ============================================================

  void _addDelta(List<_Delta> deltas, String loc, String sku, String lot, String status, double delta) {
    deltas.add(_Delta(locationId: loc, skuId: sku, lotId: lot, status: status, delta: delta));
  }

  void _addLedger(
      List<_LedgerWrite> ledgers,
      DocumentLine line,
      String loc,
      String sku,
      String lot,
      String status,
      double delta,
      ) {
    ledgers.add(_LedgerWrite(
      lineId: line.id,
      locationId: loc,
      skuId: sku,
      lotId: lot,
      status: status,
      delta: delta,
    ));
  }

  String _ensureNoLot(String skuId) {
    // try existing
    for (final v in lotsBox.values) {
      final lot = Lot.fromJson(jsonDecode(v));
      if (lot.skuId == skuId && lot.lotCode == 'NOLOT') return lot.id;
    }

    final lot = Lot(
      id: _uuid.v4(),
      skuId: skuId,
      lotCode: 'NOLOT',
      expiryIso: null,
      blocked: false,
    );
    lotsBox.put(lot.id, jsonEncode(lot.toJson()));
    return lot.id;
  }

  Future<String> _nextDocNo(String docType) async {
    final year = DateTime.now().year;
    final key = '$docType-$year';
    final cur = int.tryParse(countersBox.get(key) ?? '0') ?? 0;
    final next = cur + 1;
    await countersBox.put(key, next.toString());
    return '$docType-$year-${next.toString().padLeft(6, '0')}';
  }
}

// ============================================================
// Internal types
// ============================================================

class _Delta {
  final String locationId;
  final String skuId;
  final String lotId;
  final String status;
  final double delta;

  _Delta({
    required this.locationId,
    required this.skuId,
    required this.lotId,
    required this.status,
    required this.delta,
  });
}

class _LedgerWrite {
  final String lineId;
  final String locationId;
  final String skuId;
  final String lotId;
  final String status;
  final double delta;

  _LedgerWrite({
    required this.lineId,
    required this.locationId,
    required this.skuId,
    required this.lotId,
    required this.status,
    required this.delta,
  });
}

class _Alloc {
  final String lotId;
  final double qty;

  _Alloc({required this.lotId, required this.qty});
}
