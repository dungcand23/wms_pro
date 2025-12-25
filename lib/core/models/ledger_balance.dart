class LedgerEntry {
  final String id;
  final String tsIso;
  final String docId;
  final String docNo;
  final String docType;
  final String lineId;

  final String locationId;
  final String skuId;
  final String lotId;
  final String status; // AVAILABLE/HOLD

  final num qtyDeltaBase;

  LedgerEntry({
    required this.id,
    required this.tsIso,
    required this.docId,
    required this.docNo,
    required this.docType,
    required this.lineId,
    required this.locationId,
    required this.skuId,
    required this.lotId,
    required this.status,
    required this.qtyDeltaBase,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tsIso': tsIso,
    'docId': docId,
    'docNo': docNo,
    'docType': docType,
    'lineId': lineId,
    'locationId': locationId,
    'skuId': skuId,
    'lotId': lotId,
    'status': status,
    'qtyDeltaBase': qtyDeltaBase,
  };

  static LedgerEntry fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'],
    tsIso: j['tsIso'],
    docId: j['docId'],
    docNo: j['docNo'],
    docType: j['docType'],
    lineId: j['lineId'],
    locationId: j['locationId'],
    skuId: j['skuId'],
    lotId: j['lotId'],
    status: j['status'],
    qtyDeltaBase: j['qtyDeltaBase'],
  );
}

class BalanceRow {
  final String key; // tenant|loc|sku|lot|status
  final String locationId;
  final String skuId;
  final String lotId;
  final String status;
  final num qtyBase;
  final String updatedAtIso;

  BalanceRow({
    required this.key,
    required this.locationId,
    required this.skuId,
    required this.lotId,
    required this.status,
    required this.qtyBase,
    required this.updatedAtIso,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'locationId': locationId,
    'skuId': skuId,
    'lotId': lotId,
    'status': status,
    'qtyBase': qtyBase,
    'updatedAtIso': updatedAtIso,
  };

  static BalanceRow fromJson(Map<String, dynamic> j) => BalanceRow(
    key: j['key'],
    locationId: j['locationId'],
    skuId: j['skuId'],
    lotId: j['lotId'],
    status: j['status'],
    qtyBase: j['qtyBase'],
    updatedAtIso: j['updatedAtIso'],
  );
}
