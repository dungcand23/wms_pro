import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:wms_pro/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../ui/widgets/section_title.dart';

final balancesRefreshProvider = StreamProvider<void>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchBalances();
});

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  late final List<PlutoColumn> columns;

  @override
  void initState() {
    super.initState();
    columns = [
      PlutoColumn(title: 'Warehouse', field: 'wh', type: PlutoColumnType.text(), width: 120),
      PlutoColumn(title: 'Location', field: 'loc', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'SKU', field: 'sku', type: PlutoColumnType.text(), width: 120),
      PlutoColumn(title: 'Lot', field: 'lot', type: PlutoColumnType.text(), width: 140),
      PlutoColumn(title: 'Expiry', field: 'exp', type: PlutoColumnType.text(), width: 110),
      PlutoColumn(title: 'Status', field: 'st', type: PlutoColumnType.text(), width: 110),
      PlutoColumn(title: 'Qty(Base)', field: 'qty', type: PlutoColumnType.number(), width: 120),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    ref.watch(balancesRefreshProvider);

    final db = ref.watch(localDbProvider);
    final balances = db.getBalances();
    final skus = {for (final s in db.getSkus()) s.id: s};
    final lots = {for (final l in db.getLots()) l.id: l};
    final locs = {for (final l in db.getLocations()) l.id: l};

    final rows = balances.map((b) {
      final loc = locs[b.locationId];
      final sku = skus[b.skuId];
      final lot = lots[b.lotId];
      return PlutoRow(cells: {
        'wh': PlutoCell(value: loc?.warehouseCode ?? ''),
        'loc': PlutoCell(value: loc?.code ?? b.locationId),
        'sku': PlutoCell(value: sku?.code ?? b.skuId),
        'lot': PlutoCell(value: lot?.lotCode ?? b.lotId),
        'exp': PlutoCell(value: lot?.expiryIso ?? ''),
        'st': PlutoCell(value: b.status),
        'qty': PlutoCell(value: b.qtyBase),
      });
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(t.inventory),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: PlutoGrid(
              columns: columns,
              rows: rows,
              createHeader: (stateManager) => const SizedBox.shrink(),
              configuration: const PlutoGridConfiguration(),
            ),
          ),
        ),
      ],
    );
  }
}
