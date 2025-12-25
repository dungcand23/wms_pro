class DocumentLine {
  final String id;

  final String skuId;
  final String? lotId;

  final String? fromLocationId;
  final String? toLocationId;

  /// AVAILABLE/HOLD
  final String status;

  /// for STATUS_MOVE
  final String? toStatus;

  /// input
  final String uom;
  final double qtyInput;

  /// stored truth for posting/balance
  final double qtyBase;

  final String? reasonCode;

  DocumentLine({
    required this.id,
    required this.skuId,
    required this.uom,
    required this.qtyInput,
    required this.qtyBase,
    required this.status,
    this.lotId,
    this.fromLocationId,
    this.toLocationId,
    this.toStatus,
    this.reasonCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'skuId': skuId,
    'lotId': lotId,
    'fromLocationId': fromLocationId,
    'toLocationId': toLocationId,
    'status': status,
    'toStatus': toStatus,
    'uom': uom,
    'qtyInput': qtyInput,
    'qtyBase': qtyBase,
    'reasonCode': reasonCode,
  };

  static DocumentLine fromJson(Map<String, dynamic> j) => DocumentLine(
    id: j['id'],
    skuId: j['skuId'],
    lotId: j['lotId'],
    fromLocationId: j['fromLocationId'],
    toLocationId: j['toLocationId'],
    status: j['status'],
    toStatus: j['toStatus'],
    uom: j['uom'] ?? 'BASE',
    qtyInput: ((j['qtyInput'] ?? j['qtyBase'] ?? 0) as num).toDouble(),
    qtyBase: ((j['qtyBase'] ?? 0) as num).toDouble(),
    reasonCode: j['reasonCode'],
  );
}

class Document {
  final String id;
  final String docType; // IN/OUT/TRF/ADJ/REV/STATUS_MOVE
  final String docNo;

  /// DRAFT/SUBMITTED/APPROVED/POSTED/CANCELLED/REVERSED
  final String status;

  final String warehouseCode;

  final String createdAtIso;
  final String updatedAtIso;

  final String createdBy;

  final String? refDocId; // REV references source doc
  final String? reasonCode; // required for REV (and can be used for CANCEL)
  final String? note;

  /// ✅ Phase 3: attachments metadata ids
  final List<String> attachmentIds;

  final List<DocumentLine> lines;

  Document({
    required this.id,
    required this.docType,
    required this.docNo,
    required this.status,
    required this.warehouseCode,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.createdBy,
    required this.lines,
    this.refDocId,
    this.reasonCode,
    this.note,
    this.attachmentIds = const [],
  });

  Document copyWith({
    String? status,
    String? updatedAtIso,
    String? note,
    String? refDocId,
    String? reasonCode,
    List<String>? attachmentIds,
    List<DocumentLine>? lines,
  }) {
    return Document(
      id: id,
      docType: docType,
      docNo: docNo,
      status: status ?? this.status,
      warehouseCode: warehouseCode,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      createdBy: createdBy,
      lines: lines ?? this.lines,
      refDocId: refDocId ?? this.refDocId,
      reasonCode: reasonCode ?? this.reasonCode,
      note: note ?? this.note,
      attachmentIds: attachmentIds ?? this.attachmentIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'docType': docType,
    'docNo': docNo,
    'status': status,
    'warehouseCode': warehouseCode,
    'createdAtIso': createdAtIso,
    'updatedAtIso': updatedAtIso,
    'createdBy': createdBy,
    'refDocId': refDocId,
    'reasonCode': reasonCode,
    'note': note,
    'attachmentIds': attachmentIds,
    'lines': lines.map((e) => e.toJson()).toList(),
  };

  static Document fromJson(Map<String, dynamic> j) => Document(
    id: j['id'],
    docType: j['docType'],
    docNo: j['docNo'],
    status: j['status'],
    warehouseCode: j['warehouseCode'],
    createdAtIso: j['createdAtIso'],
    updatedAtIso: j['updatedAtIso'],
    createdBy: j['createdBy'] ?? 'system',
    refDocId: j['refDocId'],
    reasonCode: j['reasonCode'],
    note: j['note'],
    attachmentIds:
    ((j['attachmentIds'] as List?)?.cast<String>()) ?? const [],
    lines: (j['lines'] as List<dynamic>? ?? const [])
        .map((e) => DocumentLine.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
