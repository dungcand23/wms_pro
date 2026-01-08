import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final wh = ref.watch(warehouseProvider);
    final user = ref.watch(currentUserProvider);

    final pending = ref.watch(pendingCountsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: collapsed ? 70 : 260,
      child: Material(
        color: Colors.white,
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, wh, user.name, collapsed, onToggle: () {
              ref.read(sidebarCollapsedProvider.notifier).state = !collapsed;
            }),
            const SizedBox(height: 6),

            _navItem(context, collapsed: collapsed, icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/dashboard'),
            _navItem(context, collapsed: collapsed, icon: Icons.description_outlined, label: 'Documents', route: '/documents'),
            _navItem(context, collapsed: collapsed, icon: Icons.inventory_2_outlined, label: 'Inventory', route: '/inventory'),
            _navItem(context, collapsed: collapsed, icon: Icons.history_outlined, label: 'Ledger', route: '/ledger'),
            _navItem(context, collapsed: collapsed, icon: Icons.rule_outlined, label: 'Cycle Count', route: '/cycle'),
            _navItem(context, collapsed: collapsed, icon: Icons.factory_outlined, label: 'Master Data', route: '/master'),
            _navItem(context, collapsed: collapsed, icon: Icons.local_shipping_outlined, label: 'Transport', route: '/transport'),

            const SizedBox(height: 12),
            _divider(collapsed),

            _navBadge(
              context,
              collapsed: collapsed,
              icon: Icons.verified_outlined,
              label: 'Pending Approve',
              badge: pending.pendingApprove,
              route: '/documents?status=SUBMITTED',
            ),
            _navBadge(
              context,
              collapsed: collapsed,
              icon: Icons.post_add_outlined,
              label: 'Pending Post',
              badge: pending.pendingPost,
              route: '/documents?status=APPROVED',
            ),

            const Spacer(),
            _divider(collapsed),
            _navItem(context, collapsed: collapsed, icon: Icons.history_toggle_off_outlined, label: 'Audit', route: '/audit'),
            _navItem(context, collapsed: collapsed, icon: Icons.backup_outlined, label: 'Backup', route: '/backup'),
            _navItem(context, collapsed: collapsed, icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String wh,
    String userName,
    bool collapsed, {
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse_outlined, size: 26),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WMS Pro', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$wh · $userName', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ] else
            const Spacer(),
          IconButton(
            tooltip: collapsed ? 'Expand' : 'Collapse',
            onPressed: onToggle,
            icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool collapsed) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required bool collapsed,
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: collapsed ? null : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => context.go(route),
    );
  }

  Widget _navBadge(
    BuildContext context, {
    required bool collapsed,
    required IconData icon,
    required String label,
    required int badge,
    required String route,
  }) {
    return ListTile(
      dense: true,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(999)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      title: collapsed ? null : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => context.go(route),
    );
  }
}
