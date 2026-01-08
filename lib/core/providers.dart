import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user.dart';
import 'auth/firebase_auth_service.dart';
import 'remote/edge_functions_api.dart';
import 'remote/supabase_config.dart';
import 'storage/local_db.dart';
import 'sync/supabase_sync_manager.dart';

// ============================================================
// Keys
// ============================================================
const kPrefsLocale = 'locale';
const kPrefsCompact = 'compact_mode';
const kPrefsWorkflow = 'workflow_enabled';
const kPrefsSyncEnabled = 'sync_enabled';

// ============================================================
// Local DB
// ============================================================
final localDbProvider = Provider<LocalDb>((ref) => throw UnimplementedError('LocalDb not ready'));

// ============================================================
// SharedPreferences + Locale
// ============================================================
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Prefs not ready'));

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return LocaleNotifier(prefs);
});

class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences prefs;
  LocaleNotifier(this.prefs) : super(Locale(prefs.getString(kPrefsLocale) ?? 'vi'));

  Future<void> setLocale(Locale locale) async {
    await prefs.setString(kPrefsLocale, locale.languageCode);
    state = locale;
  }
}

class BoolPrefNotifier extends StateNotifier<bool> {
  final SharedPreferences prefs;
  final String key;
  final bool defaultValue;
  BoolPrefNotifier(this.prefs, {required this.key, required this.defaultValue})
      : super(prefs.getBool(key) ?? defaultValue);

  Future<void> set(bool v) async {
    await prefs.setBool(key, v);
    state = v;
  }

  Future<void> toggle() => set(!state);
}

final compactModeProvider = StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return BoolPrefNotifier(prefs, key: kPrefsCompact, defaultValue: false);
});

/// Phase 5: nếu OFF => Post trực tiếp từ DRAFT (đỡ bước submit/approve)
final workflowEnabledProvider = StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return BoolPrefNotifier(prefs, key: kPrefsWorkflow, defaultValue: true);
});

final syncEnabledProvider = StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return BoolPrefNotifier(prefs, key: kPrefsSyncEnabled, defaultValue: false);
});

// ============================================================
// User / Warehouse
// ============================================================
final warehouseProvider = StateProvider<String>((ref) => 'VN_HCM01');
final currentUserProvider = StateProvider<AppUser>((ref) => const AppUser(id: 'local', name: 'Local Admin', role: 'Admin'));

// Firebase Auth (Option B) + Edge Functions
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final edgeFunctionsApiProvider = Provider<EdgeFunctionsApi>((ref) => EdgeFunctionsApi());

// Holds latest Firebase ID token (for Edge calls).
final firebaseIdTokenProvider = StateProvider<String?>((ref) => null);

// Raw identity info returned by Edge function fb_me.
final cloudIdentityProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// Sidebar collapse
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ============================================================
// Supabase Config (persisted in Hive settings box)
// ============================================================
final supabaseConfigProvider = StateNotifierProvider<SupabaseConfigNotifier, SupabaseConfig>((ref) {
  return SupabaseConfigNotifier()..load();
});

class SupabaseConfigNotifier extends StateNotifier<SupabaseConfig> {
  SupabaseConfigNotifier() : super(const SupabaseConfig(url: '', anonKey: ''));

  static const _boxName = 'settings';
  static const _key = 'supabase_config';

  Future<void> load() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key);
    if (raw == null) return;
    state = SupabaseConfig.fromJson(jsonDecode(raw));
  }

  Future<void> save(SupabaseConfig cfg) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, jsonEncode(cfg.toJson()));
    state = cfg;
  }

  Future<void> clear() => save(const SupabaseConfig(url: '', anonKey: ''));
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final cfg = ref.watch(supabaseConfigProvider);
  if (!cfg.isValid) return null;
  return SupabaseClient(cfg.url, cfg.anonKey);
});

// ============================================================
// Online status
// ============================================================
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  // emit initial
  final first = await c.checkConnectivity();
  yield first != ConnectivityResult.none;

  await for (final r in c.onConnectivityChanged) {
    yield r != ConnectivityResult.none;
  }
});

// ============================================================
// Sync Manager (Supabase)
// ============================================================
final syncManagerProvider = Provider<SupabaseSyncManager?>((ref) {
  final enabled = ref.watch(syncEnabledProvider);
  final client = ref.watch(supabaseClientProvider);
  if (!enabled || client == null) return null;

  final onlineAsync = ref.watch(isOnlineProvider);
  final online = onlineAsync.value ?? false;
  if (!online) return null;

  final db = ref.watch(localDbProvider);
  final wh = ref.watch(warehouseProvider);

  return SupabaseSyncManager(local: db, client: client, warehouseCode: wh);
});

// ============================================================
// Pending counts for sidebar badges
// ============================================================
class PendingCounts {
  final int pendingApprove;
  final int pendingPost;
  const PendingCounts({required this.pendingApprove, required this.pendingPost});
}

final pendingCountsProvider = Provider<PendingCounts>((ref) {
  final db = ref.watch(localDbProvider);
  // trigger rebuild when docs change
  ref.watch(_docsWatchProvider);

  final docs = db.getDocuments();
  final pendingApprove = docs.where((d) => d.status == 'SUBMITTED').length;
  final pendingPost = docs.where((d) => d.status == 'APPROVED').length;

  return PendingCounts(pendingApprove: pendingApprove, pendingPost: pendingPost);
});

final _docsWatchProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchDocs();
});