class AttachmentRef {
  final String id;
  final String docId;
  final String fileName;
  final String mime;
  final int sizeBytes;

  /// Phase 3 local MVP: chỉ lưu metadata + note (file thật Phase 4)
  final String? note;

  final String createdAtIso;
  final String createdBy;

  AttachmentRef({
    required this.id,
    required this.docId,
    required this.fileName,
    required this.mime,
    required this.sizeBytes,
    required this.createdAtIso,
    required this.createdBy,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'docId': docId,
    'fileName': fileName,
    'mime': mime,
    'sizeBytes': sizeBytes,
    'note': note,
    'createdAtIso': createdAtIso,
    'createdBy': createdBy,
  };

  static AttachmentRef fromJson(Map<String, dynamic> j) => AttachmentRef(
    id: j['id'],
    docId: j['docId'],
    fileName: j['fileName'],
    mime: j['mime'],
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    note: j['note'],
    createdAtIso: j['createdAtIso'],
    createdBy: j['createdBy'],
  );
}
