class Lot {
  final String id;
  final String skuId;
  final String lotCode;
  final String? expiryIso; // yyyy-MM-dd
  final bool blocked;

  Lot({
    required this.id,
    required this.skuId,
    required this.lotCode,
    this.expiryIso,
    this.blocked = false,
  });

  DateTime? get expiry =>
      expiryIso == null ? null : DateTime.tryParse(expiryIso!);

  Map<String, dynamic> toJson() => {
    'id': id,
    'skuId': skuId,
    'lotCode': lotCode,
    'expiryIso': expiryIso,
    'blocked': blocked,
  };

  static Lot fromJson(Map<String, dynamic> j) => Lot(
    id: j['id'],
    skuId: j['skuId'],
    lotCode: j['lotCode'],
    expiryIso: j['expiryIso'],
    blocked: (j['blocked'] ?? false) as bool,
  );
}
