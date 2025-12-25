import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'storage/local_db.dart';
import 'remote/appwrite_config.dart';
import 'remote/appwrite_service.dart';
import 'sync/sync_manager.dart';
import 'models/user.dart';

// ===== Local DB =====
final localDbProvider = Provider<LocalDb>((ref) => throw UnimplementedError('LocalDb not ready'));

// ===== User/Warehouse (bạn đã có trước đó) =====
final warehouseProvider = StateProvider<String>((ref) => 'VN_HCM01');
final currentUserProvider = StateProvider<AppUser>((ref) => AppUser(id: 'local', role: 'Admin'));

// Sidebar collapse (bạn đang dùng)
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ===== Appwrite config persisted =====
final appwriteConfigProvider = StateNotifierProvider<AppwriteConfigNotifier, AppwriteConfig>((ref) {
  return AppwriteConfigNotifier();
});

class AppwriteConfigNotifier extends StateNotifier<AppwriteConfig> {
  AppwriteConfigNotifier() : super(const AppwriteConfig(endpoint: '', projectId: ''));

  static const _boxName = 'settings';
  static const _key = 'appwrite_config';

  Future<void> load() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key);
    if (raw == null) return;
    state = AppwriteConfig.fromJson(jsonDecode(raw));
  }

  Future<void> save(AppwriteConfig cfg) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, jsonEncode(cfg.toJson()));
    state = cfg;
  }
}

// ===== Appwrite service (nullable if config invalid) =====
final appwriteServiceProvider = Provider<AppwriteService?>((ref) {
  final cfg = ref.watch(appwriteConfigProvider);
  if (!cfg.isValid) return null;
  return AppwriteService.fromConfig(cfg, selfSigned: true);
});

// ===== Online status =====
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  await for (final r in c.onConnectivityChanged) {
    yield r != ConnectivityResult.none;
  }
});

// ===== Sync manager =====
final syncManagerProvider = Provider<SyncManager?>((ref) {
  final svc = ref.watch(appwriteServiceProvider);
  final onlineAsync = ref.watch(isOnlineProvider);
  if (svc == null) return null;
  final online = onlineAsync.value ?? false;
  final db = ref.watch(localDbProvider);

  return SyncManager(
    local: db,
    remote: svc,
    isOnline: online,
  );
});
