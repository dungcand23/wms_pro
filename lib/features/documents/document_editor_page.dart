import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:wms_pro/l10n/gen/app_localizations.dart';
import '../../core/models/document.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../ui/widgets/section_title.dart';
import '../../ui/widgets/split_pane.dart';

class DocumentEditorPage extends ConsumerStatefulWidget {
  final String? docId;
  final String? docType;

  const DocumentEditorPage.newDoc({super.key, required this.docType}) : docId = null;
  const DocumentEditorPage.edit({super.key, required this.docId}) : docType = null;

  @override
  ConsumerState<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends ConsumerState<DocumentEditorPage> {
  final _uuid = const Uuid();
  Document? doc;

  String? selectedFromLocId;
  String? selectedToLocId;
  String? selectedSkuId;
  String? selectedLotId;
  String? selectedUom;
  String? selectedReason;

  final qtyCtrl = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(localDbProvider);
      final wh = ref.read(warehouseProvider);
      final actor = ref.read(currentUserProvider);

      if (widget.docId != null) {
        setState(() => doc = db.getDocument(widget.docId!));
      } else {
        final created = await db.createNewDocument(
          actor: actor,
          docType: widget.docType!,
          warehouseCode: wh,
        );
        setState(() => doc = created);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final db = ref.watch(localDbProvider);
    final actor = ref.watch(currentUserProvider);

    final current = doc;
    if (current == null) return const Center(child: CircularProgressIndicator());

    final locations = db.getLocations(warehouseCode: current.warehouseCode);
    final skus = db.getSkus();
    final reasons = db.getReasonCodes();

    selectedFromLocId ??= locations.isNotEmpty ? locations.first.id : null;
    selectedToLocId ??= locations.length > 1 ? locations[1].id : selectedFromLocId;
    selectedSkuId ??= skus.isNotEmpty ? skus.first.id : null;

    final uoms = selectedSkuId == null ? const [] : db.getUoms(selectedSkuId!);
    selectedUom ??= uoms.isNotEmpty ? uoms.first.uom : 'PCS';

    final lots = selectedSkuId == null ? const [] : db.getLots(skuId: selectedSkuId);
    selectedLotId ??= lots.isNotEmpty ? lots.first.id : null;

    selectedReason ??= reasons.isNotEmpty ? reasons.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Documents / ${current.docType} • ${current.docNo}'),
        const SizedBox(height: 12),
        Expanded(
          child: SplitPane(
            left: _leftPanel(t, actor, db, locations, skus, lots, uoms, reasons),
            center: _centerPanel(db, current),
            right: _rightPanel(t, db, current),
          ),
        ),
        const SizedBox(height: 10),
        _bottomBar(db, actor, current),
      ],
    );
  }

  Widget _leftPanel(
      AppLocalizations t,
      AppUser actor,
      dynamic db,
      List locations,
      List skus,
      List lots,
      List uoms,
      List reasons,
      ) {
    final current = doc!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.scanInput, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            if (current.docType == 'IN') ...[
              _ddLoc('To LOC', selectedToLocId, locations, (v) => setState(() => selectedToLocId = v)),
            ] else if (current.docType == 'OUT') ...[
              _ddLoc('From LOC', selectedFromLocId, locations, (v) => setState(() => selectedFromLocId = v)),
            ] else if (current.docType == 'TRF') ...[
              _ddLoc('From LOC', selectedFromLocId, locations, (v) => setState(() => selectedFromLocId = v)),
              const SizedBox(height: 10),
              _ddLoc('To LOC', selectedToLocId, locations, (v) => setState(() => selectedToLocId = v)),
            ] else ...[
              _ddLoc('Location', selectedFromLocId, locations, (v) => setState(() => selectedFromLocId = v)),
            ],

            const SizedBox(height: 10),
            _ddSku('SKU', selectedSkuId, skus, (v) {
              setState(() {
                selectedSkuId = v;
                selectedUom = null;
                selectedLotId = null;
              });
            }),

            const SizedBox(height: 10),
            _ddUom('UOM', selectedUom, uoms, (v) => setState(() => selectedUom = v)),

            const SizedBox(height: 10),
            // OUT: Staff không được chọn lot (spec: chỉ Supervisor override)
            if (current.docType == 'OUT' && !actor.isSupervisor) ...[
              const Text('LOT: AUTO (FEFO) • Staff không được chọn LOT', style: TextStyle(fontSize: 12)),
            ] else ...[
              _ddLot('LOT (optional)', selectedLotId, lots, (v) => setState(() => selectedLotId = v)),
            ],

            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'Qty (input)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),

            if (current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') ...[
              const SizedBox(height: 10),
              _ddReason('Reason Code', selectedReason, reasons, (v) => setState(() => selectedReason = v)),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addLine(db),
                icon: const Icon(Icons.add),
                label: Text(t.addLineEnter),
              ),
            ),
            const SizedBox(height: 12),
            const Text('OUT: bỏ LOT => FEFO AUTO. Chọn LOT thủ công => Supervisor.', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _centerPanel(dynamic db, Document current) {
    final skus = {for (final s in db.getSkus()) s.id: s};
    final lots = {for (final l in db.getLots()) l.id: l};
    final locs = {for (final l in db.getLocations()) l.id: l};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lines', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: current.lines.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final ln = current.lines[i];
                  final sku = skus[ln.skuId]?.code ?? ln.skuId;
                  final lot = ln.lotId == null ? 'AUTO' : (lots[ln.lotId!]?.lotCode ?? ln.lotId);
                  final from = ln.fromLocationId == null ? '-' : (locs[ln.fromLocationId!]?.code ?? ln.fromLocationId);
                  final to = ln.toLocationId == null ? '-' : (locs[ln.toLocationId!]?.code ?? ln.toLocationId);

                  return ListTile(
                    title: Text(
                      '$sku • $lot • ${ln.qtyInput} ${ln.uom} (base=${ln.qtyBase})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('from=$from → to=$to • st=${ln.status}${ln.toStatus != null ? '→${ln.toStatus}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: current.status == 'DRAFT'
                          ? () async {
                        final actor = ref.read(currentUserProvider);
                        await db.removeLine(actor, current.id, ln.id);
                        setState(() => doc = db.getDocument(current.id));
                      }
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPanel(AppLocalizations t, dynamic db, Document current) {
    final locId = selectedFromLocId ?? selectedToLocId;
    final skuId = selectedSkuId;

    double avail = 0;
    double hold = 0;

    final balances = db.getBalances();
    if (locId != null && skuId != null) {
      for (final b in balances) {
        if (b.locationId == locId && b.skuId == skuId) {
          if (b.status == 'AVAILABLE') avail += (b.qtyBase as num).toDouble();
          if (b.status == 'HOLD') hold += (b.qtyBase as num).toDouble();
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.stockCheck, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _kv('AVAILABLE', avail.toString()),
            _kv('HOLD', hold.toString()),
            const Divider(height: 22),
            const Text('Rules:', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('• Không âm tồn', style: TextStyle(fontSize: 12)),
            const Text('• OUT/TRF chỉ AVAILABLE', style: TextStyle(fontSize: 12)),
            const Text('• FEFO mặc định, lot expired cần Supervisor', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(dynamic db, AppUser actor, Document current) {
    Future<void> reload() async => setState(() => doc = db.getDocument(current.id));

    Future<void> act(Future<void> Function() fn) async {
      try {
        await fn();
        await reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OK')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    final canSubmit = current.status == 'DRAFT';
    final canApprove = current.status == 'SUBMITTED' && actor.canApprove;
    final canPost = current.status == 'APPROVED' && actor.canPost;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text('Status: ${current.status}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),

            // Cancel before POSTED
            OutlinedButton(
              onPressed: (current.status == 'POSTED' || current.status == 'CANCELLED')
                  ? null
                  : () => act(() => db.cancel(actor, current.id, reason: 'CANCEL')),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),

            // Reverse after POSTED
            OutlinedButton(
              onPressed: (current.status == 'POSTED' && current.docType != 'REV')
                  ? () async {
                final rev = await db.createReverseDoc(actor, current.id, reasonCode: 'COUNT');
                if (!mounted) return;
                // open newly created rev in-place
                setState(() => doc = rev);
              }
                  : null,
              child: const Text('Reverse'),
            ),
            const SizedBox(width: 8),

            ElevatedButton(
              onPressed: canSubmit ? () => act(() => db.submit(actor, current.id)) : null,
              child: const Text('Submit'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canApprove ? () => act(() => db.approve(actor, current.id)) : null,
              child: const Text('Approve'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canPost ? () => act(() => db.post(actor, current.id)) : null,
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );

  DropdownButtonFormField<String> _ddLoc(String label, String? value, List items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) {
        final id = (e as dynamic).id as String;
        final txt = (e as dynamic).code as String;
        return DropdownMenuItem(value: id, child: Text(txt));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  DropdownButtonFormField<String> _ddSku(String label, String? value, List items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) {
        final id = (e as dynamic).id as String;
        final txt = (e as dynamic).code as String;
        return DropdownMenuItem(value: id, child: Text(txt));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  DropdownButtonFormField<String> _ddUom(String label, String? value, List items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) {
        final txt = (e as dynamic).uom as String;
        return DropdownMenuItem(value: txt, child: Text(txt));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  DropdownButtonFormField<String> _ddLot(String label, String? value, List items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) {
        final id = (e as dynamic).id as String;
        final txt = (e as dynamic).lotCode as String;
        return DropdownMenuItem(value: id, child: Text(txt));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  DropdownButtonFormField<String> _ddReason(String label, String? value, List items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e as String, child: Text(e as String))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Future<void> _addLine(dynamic db) async {
    final actor = ref.read(currentUserProvider);
    final current = doc!;
    if (selectedSkuId == null || selectedUom == null) return;

    final qtyInput = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qtyInput == 0) return;

    final sku = db.getSkus().firstWhere((s) => s.id == selectedSkuId);
    final qtyBase = db.convertToBaseOrThrow(sku, selectedUom, qtyInput);

    final manualLotAllowed = actor.isSupervisor;
    final lotId = (current.docType == 'OUT' && !manualLotAllowed) ? null : selectedLotId;

    final line = DocumentLine(
      id: _uuid.v4(),
      skuId: selectedSkuId!,
      lotId: lotId, // OUT staff => null => FEFO
      fromLocationId: current.docType == 'IN' ? null : selectedFromLocId,
      toLocationId: (current.docType == 'IN' || current.docType == 'TRF') ? selectedToLocId : null,
      status: 'AVAILABLE',
      toStatus: current.docType == 'STATUS_MOVE' ? 'HOLD' : null,
      uom: selectedUom!,
      qtyInput: qtyInput,
      qtyBase: qtyBase,
      reasonCode: (current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') ? selectedReason : null,
    );

    await db.addLine(actor, current.id, line);
    setState(() => doc = db.getDocument(current.id));
  }
}
