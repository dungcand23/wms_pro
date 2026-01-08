import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../dialogs/global_search_dialog.dart';
import '../dialogs/new_doc_dialog.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wh = ref.watch(warehouseProvider);
    final user = ref.watch(currentUserProvider);
    final online = ref.watch(isOnlineProvider).value ?? false;
    final syncEnabled = ref.watch(syncEnabledProvider);
    final sync = ref.watch(syncStatusProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(wh, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          _pill(label: user.name, ok: true),
          const SizedBox(width: 6),
          _pill(label: user.role),
          const SizedBox(width: 6),
          _pill(label: online ? 'Online' : 'Offline', ok: online),
          const SizedBox(width: 6),
          if (syncEnabled) ...[
            _pill(label: sync.isSyncing ? 'Syncing…' : 'Sync ON', ok: true),
            const SizedBox(width: 6),
            if (sync.lastError != null) _pill(label: 'Sync error', ok: false),
            if (sync.lastError != null) const SizedBox(width: 6),
            if (sync.lastSyncIso != null) _pill(label: 'Last ${_hhmm(sync.lastSyncIso!)}', ok: true),
            const SizedBox(width: 6),
          ],

          const Spacer(),

          IconButton(
            tooltip: 'Global search (Ctrl+K)',
            onPressed: () => showDialog(context: context, builder: (_) => const GlobalSearchDialog()),
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => const NewDocDialog()),
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _pill({required String label, bool? ok}) {
    final color = ok == null ? Colors.blueGrey : (ok ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12)),
    );
  }

  String _hhmm(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return '--:--';
    }
  }
}
