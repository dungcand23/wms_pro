import 'package:go_router/go_router.dart';

import '../../ui/shell/app_shell.dart';
import '../../features/dashboard/ops_dashboard_page.dart';
import '../../features/dashboard/reports_dashboard_page.dart';
import '../../features/inventory/inventory_page.dart';
import '../../features/documents/documents_list_page.dart';
import '../../features/documents/document_editor_page.dart';
import 'package:wms_pro/features/transport/transport_page.dart';
import 'package:wms_pro/features/audit/audit_page.dart';
import 'package:wms_pro/features/backup/backup_page.dart';
import 'package:wms_pro/features/cycle_count/cycle_count_page.dart';



class AppRouter {
  static final router = GoRouter(
    initialLocation: '/ops',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/ops', builder: (context, state) => const OpsDashboardPage()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsDashboardPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryPage()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsListPage()),
          GoRoute(
            path: '/documents/new/:type',
            builder: (context, state) {
              final type = state.pathParameters['type'] ?? 'OUT';
              return DocumentEditorPage.newDoc(docType: type);
            },
          ),
          GoRoute(
            path: '/documents/edit/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return DocumentEditorPage.edit(docId: id);
            },
          ),
          GoRoute(
            path: '/transport',
            builder: (context, state) => const TransportPage(),
          ),
          GoRoute(path: '/audit', builder: (_, __) => const AuditPage()),
          GoRoute(path: '/backup', builder: (_, __) => const BackupPage()),
          GoRoute(path: '/cycle', builder: (_, __) => const CycleCountPage()),
        ],
      ),
    ],
  );
}
