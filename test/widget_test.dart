import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wms_pro/app.dart';
import 'package:wms_pro/core/providers.dart';
import 'package:wms_pro/core/storage/local_db.dart';

void main() {
  late Directory tempDir;
  late LocalDb db;

  setUpAll(() async {
    // SharedPreferences mock
    SharedPreferences.setMockInitialValues({});

    // Init Hive for VM tests
    tempDir = await Directory.systemTemp.createTemp('wms_pro_test_');
    Hive.init(tempDir.path);

    // Open Local DB (Hive boxes)
    db = await LocalDb.open();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('WmsApp builds without crashing', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          // localeProvider is a StateNotifierProvider -> override must return LocaleNotifier
          localeProvider.overrideWith((ref) => LocaleNotifier(prefs)),
          localDbProvider.overrideWithValue(db),
        ],
        child: const WmsApp(),
      ),
    );

    // Let router/layout settle
    await tester.pumpAndSettle();

    // Smoke assertions
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
