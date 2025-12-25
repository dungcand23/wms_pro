class AppUser {
  final String id;
  final String name;
  final String role; // Admin/Staff/Supervisor/Poster/Viewer

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
  });

  bool get isSupervisor => role == 'Supervisor' || role == 'Admin';
  bool get canPost => role == 'Poster' || role == 'Supervisor' || role == 'Admin';
  bool get canApprove => role == 'Supervisor' || role == 'Admin';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  static AppUser fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    name: j['name'],
    role: j['role'],
  );
}
