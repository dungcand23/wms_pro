import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  static const double wExpanded = 220; // ✅ giảm bề ngang
  static const double wCollapsed = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: collapsed ? wCollapsed : wExpanded,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF173A73), Color(0xFF0D2B55)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(context, ref, collapsed),
            const SizedBox(height: 6),

            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.dashboard_outlined,
              label: 'Vận hành - Hôm nay',
              route: '/ops',
            ),
            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.local_shipping_outlined,
              label: 'Vận tải',
              route: '/transport',
            ),
            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.bar_chart_outlined,
              label: 'Báo cáo',
              route: '/reports',
            ),
            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.inventory_2_outlined,
              label: 'Tồn kho',
              route: '/inventory',
            ),
            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.description_outlined,
              label: 'Chứng từ',
              route: '/documents',
            ),

            const SizedBox(height: 12),
            _divider(collapsed),

            _navBadge(
              context,
              collapsed: collapsed,
              icon: Icons.verified_outlined,
              label: 'Chờ duyệt',
              badge: 2,
              route: '/documents?tab=pending_approve',
            ),
            _navBadge(
              context,
              collapsed: collapsed,
              icon: Icons.publish_outlined,
              label: 'Chờ post',
              badge: 4,
              route: '/documents?tab=pending_post',
            ),

            const Spacer(),
            _divider(collapsed),
            _navItem(
              context,
              collapsed: collapsed,
              icon: Icons.settings_outlined,
              label: 'Cấu hình',
              route: '/settings',
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, bool collapsed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // ✅ compact hơn
      child: Row(
        children: [
          const Icon(Icons.warehouse_outlined, color: Colors.white),
          const SizedBox(width: 10),
          if (!collapsed)
            const Expanded(
              child: Text(
                'WMS Pro',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          IconButton(
            tooltip: collapsed ? 'Mở rộng' : 'Thu gọn',
            onPressed: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
            icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool collapsed) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
      child: const Divider(color: Colors.white24, height: 16),
    );
  }

  Widget _navItem(
      BuildContext context, {
        required bool collapsed,
        required IconData icon,
        required String label,
        required String route,
      }) {
    final selected = GoRouterState.of(context).uri.toString().startsWith(route.split('?').first);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10, vertical: 3), // ✅ sát hơn
      child: Material(
        color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(route),
          child: SizedBox(
            height: 44, // ✅ item thấp hơn → nhìn “sát” hơn
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(route),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
