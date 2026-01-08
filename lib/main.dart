import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (Option B: Firebase Auth)
  // This will be a no-op until you put real values into firebase_options.dart.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Keep app usable in local/offline mode even when Firebase isn't configured yet.
  }


  await Hive.initFlutter();
  final db = await LocalDb.open();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        localDbProvider.overrideWithValue(db),
      ],
      child: const WmsApp(),
    ),
  );
}
