class Sku {
  final String id;
  final String code;
  final String name;

  /// EA = integer base, KG = decimal 3
  final String baseType;
  final String baseUom;

  Sku({
    required this.id,
    required this.code,
    required this.name,
    required this.baseType,
    required this.baseUom,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'baseType': baseType,
    'baseUom': baseUom,
  };

  static Sku fromJson(Map<String, dynamic> j) => Sku(
    id: j['id'],
    code: j['code'],
    name: j['name'],
    baseType: j['baseType'],
    baseUom: j['baseUom'],
  );
}
