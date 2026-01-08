import 'package:flutter/material.dart';

import '../../core/sync/sync_runner.dart';
import '../../core/shortcuts/app_shortcuts.dart';
import '../dialogs/global_search_dialog.dart';
import '../dialogs/new_doc_dialog.dart';
import 'sidebar.dart';
import 'top_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Shortcuts(
      shortcuts: AppShortcuts.bindings(),
      child: Actions(
        actions: {
          GlobalSearchIntent: CallbackAction<GlobalSearchIntent>(
            onInvoke: (_) {
              showDialog(context: context, builder: (_) => const GlobalSearchDialog());
              return null;
            },
          ),
          NewDocIntent: CallbackAction<NewDocIntent>(
            onInvoke: (_) {
              showDialog(context: context, builder: (_) => const NewDocDialog());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: SyncRunner(
            child: Scaffold(
            body: Row(
              children: [
                const Sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      const TopBar(),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(isWide ? 12 : 8),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
