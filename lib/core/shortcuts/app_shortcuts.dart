import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class GlobalSearchIntent extends Intent {
  const GlobalSearchIntent();
}

class NewDocIntent extends Intent {
  const NewDocIntent();
}

class AppShortcuts {
  static Map<ShortcutActivator, Intent> bindings() => const {
    SingleActivator(LogicalKeyboardKey.keyK, control: true): GlobalSearchIntent(),
    SingleActivator(LogicalKeyboardKey.f2): NewDocIntent(),
  };
}
