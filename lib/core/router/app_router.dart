import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/audit_page.dart';
import '../../features/backup/backup_page.dart';
import '../../features/cycle_count/cycle_count_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/documents/document_editor_page.dart';
import '../../features/documents/documents_list_page.dart';
import '../../features/inventory/inventory_page.dart';
import '../../features/ledger/ledger_page.dart';
import '../../features/master/master_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/transport/transport_page.dart';
import '../../ui/shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => DocumentsListPage(initialStatus: state.uri.queryParameters['status']),
          ),
          GoRoute(
            path: '/documents/new/:type',
            builder: (context, state) => DocumentEditorPage.newDoc(
              docType: state.pathParameters['type'] ?? 'IN',
            ),
          ),
          GoRoute(
            path: '/documents/:id',
            builder: (context, state) => DocumentEditorPage.edit(
              docId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => InventoryPage(
              initialSku: state.uri.queryParameters['sku'],
              initialLoc: state.uri.queryParameters['loc'],
            ),
          ),
          GoRoute(
            path: '/ledger',
            builder: (context, state) => const LedgerPage(),
          ),
          GoRoute(
            path: '/cycle',
            builder: (context, state) => const CycleCountPage(),
          ),
          GoRoute(
            path: '/master',
            builder: (context, state) => const MasterDataPage(),
          ),
          GoRoute(
            path: '/transport',
            builder: (context, state) => const TransportPage(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditPage(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});
