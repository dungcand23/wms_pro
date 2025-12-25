class AppwriteConfig {
  final String endpoint;
  final String projectId;

  const AppwriteConfig({
    required this.endpoint,
    required this.projectId,
  });

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'projectId': projectId,
  };

  static AppwriteConfig fromJson(Map<String, dynamic> j) => AppwriteConfig(
    endpoint: j['endpoint'] ?? '',
    projectId: j['projectId'] ?? '',
  );

  bool get isValid => endpoint.isNotEmpty && projectId.isNotEmpty;
}
