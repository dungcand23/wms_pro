// lib/ui/shell/top_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wh = ref.watch(warehouseProvider);
    final user = ref.watch(currentUserProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          // LEFT (always shrink safely)
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'WMS Pro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'WH: $wh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // RIGHT ACTIONS (scrollable => never overflow)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip('Role: ${user.role}'),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () {
                      // placeholder: bạn có thể gọi ref.invalidate(...) nếu cần
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () {
                      // placeholder
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withOpacity(0.05),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
