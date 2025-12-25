import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shortcuts/app_shortcuts.dart';
import 'sidebar.dart';
import 'top_bar.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: AppShortcuts.bindings(),
      child: Actions(
        actions: {
          GlobalSearchIntent: CallbackAction<GlobalSearchIntent>(
            onInvoke: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('TODO: Global Search (Ctrl+K)')),
              );
              return null;
            },
          ),
          NewDocIntent: CallbackAction<NewDocIntent>(
            onInvoke: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('TODO: New Document (F2)')),
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 1100;
              return Scaffold(
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
              );
            },
          ),
        ),
      ),
    );
  }
}
