import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:wms_pro/l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../ui/widgets/section_title.dart';

final balancesRefreshProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchBalances();
});

class InventoryPage extends ConsumerStatefulWidget {
  final String? initialSku;
  final String? initialLoc;

  const InventoryPage({super.key, this.initialSku, this.initialLoc});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  late final TextEditingController skuCtrl;
  late final TextEditingController locCtrl;
  final FocusNode _skuFocus = FocusNode();

  bool onlyQtyGt0 = true;

  @override
  void initState() {
    super.initState();
    skuCtrl = TextEditingController(text: widget.initialSku ?? '');
    locCtrl = TextEditingController(text: widget.initialLoc ?? '');
  }

  @override
  void dispose() {
    skuCtrl.dispose();
    locCtrl.dispose();
    _skuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    ref.watch(balancesRefreshProvider);

    final compact = ref.watch(compactModeProvider);

    final db = ref.watch(localDbProvider);
    final wh = ref.watch(warehouseProvider);

    final skuMap = {for (final s in db.getSkus()) s.id: s.code};
    final locMap = {for (final l in db.getLocations(warehouseCode: wh)) l.id: l.code};
    final lotMap = {for (final l in db.getLots()) l.id: l.lotCode};

    final skuQ = skuCtrl.text.trim().toLowerCase();
    final locQ = locCtrl.text.trim().toLowerCase();

    final balances = db.getBalances();
    final filtered = balances.where((b) {
      if (onlyQtyGt0 && (b.qtyBase <= 0)) return false;
      final skuCode = (skuMap[b.skuId] ?? b.skuId).toLowerCase();
      final locCode = (locMap[b.locationId] ?? b.locationId).toLowerCase();
      if (skuQ.isNotEmpty && !skuCode.contains(skuQ)) return false;
      if (locQ.isNotEmpty && !locCode.contains(locQ)) return false;
      return true;
    }).toList();

    final columns = <PlutoColumn>[
      PlutoColumn(title: l10n.warehouse, field: 'warehouse', type: PlutoColumnType.text(), width: 120),
      PlutoColumn(title: l10n.location, field: 'location', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: l10n.sku, field: 'sku', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: 'Lot', field: 'lot', type: PlutoColumnType.text(), width: 160),
      PlutoColumn(title: l10n.status, field: 'status', type: PlutoColumnType.text(), width: 120),
      PlutoColumn(title: l10n.qty, field: 'qty', type: PlutoColumnType.number(), width: 140),
      PlutoColumn(title: 'Updated', field: 'updated', type: PlutoColumnType.text(), width: 180),
    ];

    final rows = filtered
        .map(
          (b) => PlutoRow(
            cells: {
              'warehouse': PlutoCell(value: wh),
              'location': PlutoCell(value: locMap[b.locationId] ?? b.locationId),
              'sku': PlutoCell(value: skuMap[b.skuId] ?? b.skuId),
              'lot': PlutoCell(value: lotMap[b.lotId] ?? b.lotId),
              'status': PlutoCell(value: b.status),
              'qty': PlutoCell(value: b.qtyBase),
              'updated': PlutoCell(value: b.updatedAtIso),
            },
          ),
        )
        .toList();

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Inventory'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: skuCtrl,
                  focusNode: _skuFocus,
                  decoration: const InputDecoration(
                    labelText: 'SKU contains',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location contains',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              FilterChip(
                label: const Text('Qty > 0'),
                selected: onlyQtyGt0,
                onSelected: (_) => setState(() => onlyQtyGt0 = !onlyQtyGt0),
              ),
              Chip(label: Text('Rows: ${rows.length}', style: const TextStyle(fontWeight: FontWeight.w800))),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    skuCtrl.text = '';
                    locCtrl.text = '';
                    onlyQtyGt0 = true;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: PlutoGrid(
                columns: columns,
                rows: rows,
                createHeader: (stateManager) => const SizedBox.shrink(),
                configuration: PlutoGridConfiguration(
                  style: PlutoGridStyleConfig(
                    rowHeight: compact ? 32 : 44,
                    columnHeight: compact ? 32 : 44,
                    gridBorderColor: t.dividerColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (intent) {
            _skuFocus.requestFocus();
            return null;
          }),
        },
        child: Focus(autofocus: true, child: content),
      ),
    );
  }
}
