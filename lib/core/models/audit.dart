class AuditEntry {
  final String id;
  final String tsIso;
  final String actor; // userId or name
  final String entityType; // SKU/UOM/LOC/DOC
  final String entityId;
  final String action; // CREATE/UPDATE/STATUS/POST/CANCEL/REVERSE
  final String? reason;
  final List<String> changedFields;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;

  AuditEntry({
    required this.id,
    required this.tsIso,
    required this.actor,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.changedFields,
    this.reason,
    this.beforeJson,
    this.afterJson,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tsIso': tsIso,
    'actor': actor,
    'entityType': entityType,
    'entityId': entityId,
    'action': action,
    'reason': reason,
    'changedFields': changedFields,
    'beforeJson': beforeJson,
    'afterJson': afterJson,
  };

  static AuditEntry fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'],
    tsIso: j['tsIso'],
    actor: j['actor'],
    entityType: j['entityType'],
    entityId: j['entityId'],
    action: j['action'],
    reason: j['reason'],
    changedFields: (j['changedFields'] as List<dynamic>).cast<String>(),
    beforeJson: (j['beforeJson'] as Map?)?.cast<String, dynamic>(),
    afterJson: (j['afterJson'] as Map?)?.cast<String, dynamic>(),
  );
}
