class SkuUom {
  final String skuId;
  final String uom; // e.g. PCS, BOX
  final double factorToBase; // qty_base = qty_input * factorToBase
  final bool isBase;

  const SkuUom({
    required this.skuId,
    required this.uom,
    required this.factorToBase,
    required this.isBase,
  });

  Map<String, dynamic> toJson() => {
    'skuId': skuId,
    'uom': uom,
    'factorToBase': factorToBase,
    'isBase': isBase,
  };

  static SkuUom fromJson(Map<String, dynamic> j) => SkuUom(
    skuId: j['skuId'],
    uom: j['uom'],
    factorToBase: (j['factorToBase'] as num).toDouble(),
    isBase: (j['isBase'] ?? false) as bool,
  );
}
