class LocationNode {
  final String id;
  final String warehouseCode;
  final String code;
  final String? parentId;
  final String type; // STORAGE/PICK/...

  LocationNode({
    required this.id,
    required this.warehouseCode,
    required this.code,
    required this.type,
    this.parentId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'warehouseCode': warehouseCode,
    'code': code,
    'parentId': parentId,
    'type': type,
  };

  static LocationNode fromJson(Map<String, dynamic> j) => LocationNode(
    id: j['id'],
    warehouseCode: j['warehouseCode'],
    code: j['code'],
    parentId: j['parentId'],
    type: j['type'],
  );
}
