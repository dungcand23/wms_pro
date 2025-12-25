import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wms_pro/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../ui/widgets/section_title.dart';

final documentsRefreshProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchDocs();
});

class DocumentsListPage extends ConsumerWidget {
  const DocumentsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    ref.watch(documentsRefreshProvider); // refresh on changes
    final db = ref.watch(localDbProvider);
    final docs = db.getDocuments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          t.docList,
          trailing: Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/documents/new/IN'),
                icon: const Icon(Icons.add),
                label: Text('${t.newButton} IN'),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/documents/new/OUT'),
                icon: const Icon(Icons.add),
                label: Text('${t.newButton} OUT'),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/documents/new/TRF'),
                icon: const Icon(Icons.add),
                label: Text('${t.newButton} TRF'),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/documents/new/ADJ'),
                icon: const Icon(Icons.add),
                label: Text('${t.newButton} ADJ'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                  title: Text('${d.docNo} • ${d.docType}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Status: ${d.status} • Lines: ${d.lines.length} • WH: ${d.warehouseCode}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/documents/edit/${d.id}'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
