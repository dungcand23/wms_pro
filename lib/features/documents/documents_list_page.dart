import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../core/providers.dart';
import '../../core/models/document_template.dart';
import '../../ui/widgets/section_title.dart';

final docsRefreshProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchDocs();
});

final templatesRefreshProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchTemplates();
});

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _OpenDocIntent extends Intent {
  const _OpenDocIntent();
}

class _NewDocIntent extends Intent {
  const _NewDocIntent();
}

class _DuplicateDocIntent extends Intent {
  const _DuplicateDocIntent();
}

class _FromTemplateIntent extends Intent {
  const _FromTemplateIntent();
}

class DocumentsListPage extends ConsumerStatefulWidget {
  final String? initialStatus;
  const DocumentsListPage({super.key, this.initialStatus});

  @override
  ConsumerState<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends ConsumerState<DocumentsListPage> {
  late String status;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  PlutoGridStateManager? _grid;

  @override
  void initState() {
    super.initState();
    status = widget.initialStatus ?? 'ALL';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String? _currentDocId() {
    final row = _grid?.currentRow;
    if (row == null) return null;
    final v = row.cells['id']?.value;
    return v?.toString();
  }

  Future<void> _openTemplatesDialog() async {
    final db = ref.read(localDbProvider);
    final wh = ref.read(warehouseProvider);
    final actor = ref.read(currentUserProvider);

    final all = db.getDocTemplates();
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No templates yet. Open a document and save as template.')));
      return;
    }

    DocumentTemplate? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create from template'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: all.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = all[i];
                return ListTile(
                  dense: true,
                  title: Text(t.name),
                  subtitle: Text('Type: ${t.docType} • Lines: ${t.lines.length}'),
                  onTap: () {
                    picked = t;
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );

    if (picked == null) return;
    final doc = await db.createDocumentFromTemplate(actor: actor, templateId: picked!.id, warehouseCode: wh);
    if (!mounted) return;
    context.go('/documents/${doc.id}');
  }

  Future<void> _duplicateSelected() async {
    final id = _currentDocId();
    if (id == null) return;
    final db = ref.read(localDbProvider);
    final actor = ref.read(currentUserProvider);
    final src = db.getDocument(id);
    if (src == null) return;
    if (src.status != 'DRAFT') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only DRAFT documents can be duplicated.')));
      return;
    }
    final doc = await db.duplicateDocument(actor: actor, sourceDocId: id);
    if (!mounted) return;
    context.go('/documents/${doc.id}');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(docsRefreshProvider);
    ref.watch(templatesRefreshProvider);

    final db = ref.watch(localDbProvider);
    final wh = ref.watch(warehouseProvider);
    final compact = ref.watch(compactModeProvider);

    final q = _searchCtrl.text.trim().toLowerCase();
    final all = db.getDocuments().where((d) => d.warehouseCode == wh).toList();
    final filtered = all.where((d) {
      if (status != 'ALL' && d.status != status) return false;
      if (q.isEmpty) return true;
      return d.docNo.toLowerCase().contains(q) || d.docType.toLowerCase().contains(q) || d.status.toLowerCase().contains(q);
    }).toList();

    final columns = <PlutoColumn>[
      PlutoColumn(title: 'DocNo', field: 'docNo', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'Type', field: 'type', type: PlutoColumnType.text(), width: 100),
      PlutoColumn(title: 'Status', field: 'status', type: PlutoColumnType.text(), width: 120),
      PlutoColumn(title: 'Lines', field: 'lines', type: PlutoColumnType.number(), width: 90),
      PlutoColumn(title: 'Updated', field: 'updated', type: PlutoColumnType.text(), width: 180),
      PlutoColumn(title: 'ID', field: 'id', type: PlutoColumnType.text(), width: 280, hide: true),
    ];

    final rows = filtered
        .map(
          (d) => PlutoRow(
            cells: {
              'docNo': PlutoCell(value: d.docNo),
              'type': PlutoCell(value: d.docType),
              'status': PlutoCell(value: d.status),
              'lines': PlutoCell(value: d.lines.length),
              'updated': PlutoCell(value: d.updatedAtIso),
              'id': PlutoCell(value: d.id),
            },
          ),
        )
        .toList();

    final statuses = <String>[
      'ALL',
      'DRAFT',
      'SUBMITTED',
      'APPROVED',
      'POSTED',
      'CANCELLED',
    ];

    final page = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Documents',
            trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/documents/new/IN'),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
                OutlinedButton.icon(
                  onPressed: _openTemplatesDialog,
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: const Text('From template'),
                ),
                OutlinedButton.icon(
                  onPressed: _duplicateSelected,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Duplicate'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  decoration: const InputDecoration(
                    labelText: 'Search (docNo / type / status)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String>(
                value: status,
                items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => status = v ?? 'ALL'),
              ),
              Chip(label: Text('Rows: ${rows.length}', style: const TextStyle(fontWeight: FontWeight.w800))),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  status = 'ALL';
                  _searchCtrl.text = '';
                }),
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: PlutoGrid(
                columns: columns,
                rows: rows,
                onLoaded: (e) => _grid = e.stateManager,
                configuration: PlutoGridConfiguration(
                  style: PlutoGridStyleConfig(
                    rowHeight: compact ? 32 : 44,
                    columnHeight: compact ? 32 : 44,
                  ),
                ),
                onRowDoubleTap: (_) {
                  final id = _currentDocId();
                  if (id != null) context.go('/documents/$id');
                },
              ),
            ),
          ),
        ],
      ),
    );

    // shortcuts: Ctrl+F focus search, Ctrl+N new, Ctrl+D duplicate, Enter open, Ctrl+T from template
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewDocIntent(),
        SingleActivator(LogicalKeyboardKey.keyD, control: true): _DuplicateDocIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, control: true): _FromTemplateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _OpenDocIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (_) {
            _searchFocus.requestFocus();
            return null;
          }),
          _NewDocIntent: CallbackAction<_NewDocIntent>(onInvoke: (_) {
            context.go('/documents/new/IN');
            return null;
          }),
          _DuplicateDocIntent: CallbackAction<_DuplicateDocIntent>(onInvoke: (_) {
            _duplicateSelected();
            return null;
          }),
          _FromTemplateIntent: CallbackAction<_FromTemplateIntent>(onInvoke: (_) {
            _openTemplatesDialog();
            return null;
          }),
          _OpenDocIntent: CallbackAction<_OpenDocIntent>(onInvoke: (_) {
            final id = _currentDocId();
            if (id != null) context.go('/documents/$id');
            return null;
          }),
        },
        child: Focus(autofocus: true, child: page),
      ),
    );
  }
}
