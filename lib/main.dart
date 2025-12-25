import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final db = await LocalDb.open();

  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(kPrefsLocale) ?? 'vi';

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        localeProvider.overrideWith((ref) => Locale(saved)),
        localDbProvider.overrideWithValue(db),
      ],
      child: const WmsApp(),
    ),
  );
}
