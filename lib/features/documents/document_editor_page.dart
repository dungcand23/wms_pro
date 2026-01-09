import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:wms_pro/l10n/app_localizations.dart';
import '../../core/models/document.dart';
import '../../core/models/document_template.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/scan/scan_parser.dart';
import '../../ui/widgets/section_title.dart';
import '../../ui/widgets/split_pane.dart';

class _FocusScanIntent extends Intent {
  const _FocusScanIntent();
}

class _BulkPasteIntent extends Intent {
  const _BulkPasteIntent();
}

class _SaveTemplateIntent extends Intent {
  const _SaveTemplateIntent();
}

class _PostIntent extends Intent {
  const _PostIntent();
}

class _SaveDraftIntent extends Intent {
  const _SaveDraftIntent();
}

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
  String selectedStatus = 'AVAILABLE';
  String? selectedToStatus; // used in STATUS_MOVE

  bool autoAdd = true;
  int _trfLocStep = 0; // 0=expect from, 1=expect to

  final scanCtrl = TextEditingController();
  final scanFocus = FocusNode();

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
  void dispose() {
    qtyCtrl.dispose();
    scanCtrl.dispose();
    scanFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final db = ref.watch(localDbProvider);
    final actor = ref.watch(currentUserProvider);
    final workflow = ref.watch(workflowEnabledProvider);

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

    // enforce defaults by type
    if (current.docType == 'OUT' || current.docType == 'TRF') {
      selectedStatus = 'AVAILABLE';
    }
    if (current.docType == 'STATUS_MOVE') {
      selectedToStatus ??= (selectedStatus == 'AVAILABLE' ? 'HOLD' : 'AVAILABLE');
    } else {
      selectedToStatus = null;
    }

    final content = Column(
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

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyL, control: true): _FocusScanIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _BulkPasteIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true): _SaveTemplateIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): _PostIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveDraftIntent(),
      },
      child: Actions(
        actions: {
          _FocusScanIntent: CallbackAction<_FocusScanIntent>(onInvoke: (_) {
            scanFocus.requestFocus();
            return null;
          }),
          _BulkPasteIntent: CallbackAction<_BulkPasteIntent>(onInvoke: (_) {
            _openBulkPaste(db);
            return null;
          }),
          _SaveTemplateIntent: CallbackAction<_SaveTemplateIntent>(onInvoke: (_) {
            _saveAsTemplate(db);
            return null;
          }),
          _SaveDraftIntent: CallbackAction<_SaveDraftIntent>(onInvoke: (_) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
            return null;
          }),
          _PostIntent: CallbackAction<_PostIntent>(onInvoke: (_) {
            _quickPost(db, actor, workflow);
            return null;
          }),
        },
        child: Focus(autofocus: true, child: content),
      ),
    );
  }

  Future<void> _quickPost(dynamic db, AppUser actor, bool workflowEnabled) async {
    final current = doc;
    if (current == null) return;
    final canPost = (workflowEnabled
            ? current.status == 'APPROVED'
            : (current.status == 'DRAFT' || current.status == 'APPROVED')) &&
        actor.canPost;
    if (!canPost) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot Post in current status')));
      return;
    }
    await db.post(actor, current.id);
    setState(() => doc = db.getDocument(current.id));
  }

  void _applyScan(dynamic db, String raw) {
    final current = doc;
    if (current == null) return;
    final tokens = raw.trim().split(RegExp(r'\s+'));
    for (final tok in tokens) {
      final r = parseScan(tok);
      if (r == null) continue;
      switch (r.type) {
        case 'LOC':
          _applyLocCode(db, r.value);
          break;
        case 'FROM':
          _applyLocCode(db, r.value, forceFrom: true);
          break;
        case 'TO':
          _applyLocCode(db, r.value, forceTo: true);
          break;
        case 'SKU':
          _applySkuCode(db, r.value);
          break;
        case 'LOT':
          _applyLotCode(db, r.value);
          break;
        case 'QTY':
          qtyCtrl.text = r.value;
          break;
        case 'UOM':
          _applyUom(db, r.value);
          break;
        case 'STATUS':
          setState(() => selectedStatus = r.value.toUpperCase());
          break;
      }
    }

    final okSku = selectedSkuId != null;
    final okQty = (double.tryParse(qtyCtrl.text.trim()) ?? 0) > 0;
    final okLoc = switch (current.docType) {
      'IN' => selectedToLocId != null,
      'OUT' => selectedFromLocId != null,
      'TRF' => selectedFromLocId != null && selectedToLocId != null,
      _ => selectedFromLocId != null,
    };
    final okReason = !(current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') || selectedReason != null;
    final okToStatus = current.docType != 'STATUS_MOVE' || selectedToStatus != null;

    if (autoAdd && okSku && okQty && okLoc && okReason && okToStatus) {
      _addLine(db);
      if (current.docType == 'TRF') {
        // prepare next scan quickly
        _trfLocStep = 0;
      }
    }
  }

  void _applyLocCode(dynamic db, String code, {bool forceFrom = false, bool forceTo = false}) {
    final current = doc;
    if (current == null) return;
    final c = code.trim().toUpperCase();
    final locations = db.getLocations(warehouseCode: current.warehouseCode);
    final found = locations.cast<dynamic?>().firstWhere(
          (l) => (l.code as String).toUpperCase() == c,
          orElse: () => null,
        );
    if (found == null) return;

    setState(() {
      if (forceFrom) {
        selectedFromLocId = found.id;
        return;
      }
      if (forceTo) {
        selectedToLocId = found.id;
        return;
      }
      if (current.docType == 'IN') {
        selectedToLocId = found.id;
      } else if (current.docType == 'OUT' || current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') {
        selectedFromLocId = found.id;
      } else if (current.docType == 'TRF') {
        if (_trfLocStep == 0) {
          selectedFromLocId = found.id;
          _trfLocStep = 1;
        } else {
          selectedToLocId = found.id;
          _trfLocStep = 0;
        }
      } else {
        selectedFromLocId = found.id;
      }
    });
  }

  void _applySkuCode(dynamic db, String code) {
    final c = code.trim().toUpperCase();
    final skus = db.getSkus();
    final found = skus.cast<dynamic?>().firstWhere(
          (s) => (s.code as String).toUpperCase() == c || (s.id as String).toUpperCase() == c,
          orElse: () => null,
        );
    if (found == null) return;
    final uoms = db.getUoms(found.id);
    setState(() {
      selectedSkuId = found.id;
      selectedUom = uoms.isNotEmpty ? uoms.first.uom : 'PCS';
      selectedLotId = null;
    });
  }

  void _applyLotCode(dynamic db, String lotCode) {
    final skuId = selectedSkuId;
    if (skuId == null) return;
    final c = lotCode.trim().toUpperCase();
    final lots = db.getLots(skuId: skuId);
    final found = lots.cast<dynamic?>().firstWhere(
          (l) => (l.lotCode as String).toUpperCase() == c || (l.id as String).toUpperCase() == c,
          orElse: () => null,
        );
    if (found == null) return;
    setState(() => selectedLotId = found.id);
  }

  void _applyUom(dynamic db, String uom) {
    final skuId = selectedSkuId;
    if (skuId == null) return;
    final c = uom.trim().toUpperCase();
    final uoms = db.getUoms(skuId);
    final found = uoms.cast<dynamic?>().firstWhere(
          (u) => (u.uom as String).toUpperCase() == c,
          orElse: () => null,
        );
    if (found == null) return;
    setState(() => selectedUom = found.uom);
  }

  Future<void> _openBulkPaste(dynamic db) async {
    final current = doc;
    if (current == null) return;
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bulk paste lines'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mỗi dòng 1 line. Phân tách bằng TAB hoặc dấu phẩy.\n'
                  'IN: toLoc, sku, lot(optional), qty, uom(optional), status(optional)\n'
                  'OUT: fromLoc, sku, lot(optional), qty, uom(optional)\n'
                  'TRF: fromLoc, toLoc, sku, lot(optional), qty, uom(optional)\n'
                  'ADJ: loc, sku, lot(optional), qty, uom(optional), status(optional), reason(optional)\n'
                  'STATUS_MOVE: loc, sku, lot(optional), qty, uom(optional), fromStatus(optional), toStatus(optional), reason(optional)',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'LOC_A\tSKU_1\tLOT1\t10\tPCS'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final actor = ref.read(currentUserProvider);
                final lines = ctrl.text.split(RegExp(r'\r?\n'));
                int ok = 0;
                int fail = 0;
                for (final raw in lines) {
                  final s = raw.trim();
                  if (s.isEmpty) continue;
                  final cols = s.contains('\t') ? s.split('\t') : s.split(',');
                  final c = cols.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  try {
                    await _addLineFromColumns(db, actor, current, c);
                    ok++;
                  } catch (_) {
                    fail++;
                  }
                }
                setState(() => doc = db.getDocument(current.id));
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported: $ok ok, $fail failed')));
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addLineFromColumns(dynamic db, AppUser actor, Document current, List<String> c) async {
    // helper: lookup by code
    String? locIdByCode(String code) {
      final list = db.getLocations(warehouseCode: current.warehouseCode);
      final u = code.trim().toUpperCase();
      final found = list.cast<dynamic?>().firstWhere(
            (l) => (l.code as String).toUpperCase() == u,
            orElse: () => null,
          );
      return found?.id;
    }

    String? skuIdByCode(String code) {
      final list = db.getSkus();
      final u = code.trim().toUpperCase();
      final found = list.cast<dynamic?>().firstWhere(
            (s) => (s.code as String).toUpperCase() == u || (s.id as String).toUpperCase() == u,
            orElse: () => null,
          );
      return found?.id;
    }

    String? lotIdByCode(String skuId, String code) {
      final list = db.getLots(skuId: skuId);
      final u = code.trim().toUpperCase();
      final found = list.cast<dynamic?>().firstWhere(
            (l) => (l.lotCode as String).toUpperCase() == u || (l.id as String).toUpperCase() == u,
            orElse: () => null,
          );
      return found?.id;
    }

    String? fromLocId;
    String? toLocId;
    String skuId;
    String? lotId;
    double qty;
    String uom = selectedUom ?? 'PCS';
    String status = (current.docType == 'OUT' || current.docType == 'TRF') ? 'AVAILABLE' : selectedStatus;
    String? toStatus;
    String? reason;

    if (current.docType == 'IN') {
      if (c.length < 3) throw Exception('cols');
      toLocId = locIdByCode(c[0]);
      skuId = skuIdByCode(c[1]) ?? (throw Exception('sku'));
      int idx = 2;
      if (c[idx].isNotEmpty && double.tryParse(c[idx]) == null) {
        lotId = lotIdByCode(skuId, c[idx]);
        idx++;
      }
      qty = double.parse(c[idx]);
      idx++;
      if (idx < c.length) uom = c[idx];
      idx++;
      if (idx < c.length) status = c[idx].toUpperCase();
    } else if (current.docType == 'OUT') {
      if (c.length < 3) throw Exception('cols');
      fromLocId = locIdByCode(c[0]);
      skuId = skuIdByCode(c[1]) ?? (throw Exception('sku'));
      int idx = 2;
      if (c[idx].isNotEmpty && double.tryParse(c[idx]) == null) {
        lotId = lotIdByCode(skuId, c[idx]);
        idx++;
      }
      qty = double.parse(c[idx]);
      idx++;
      if (idx < c.length) uom = c[idx];
    } else if (current.docType == 'TRF') {
      if (c.length < 4) throw Exception('cols');
      fromLocId = locIdByCode(c[0]);
      toLocId = locIdByCode(c[1]);
      skuId = skuIdByCode(c[2]) ?? (throw Exception('sku'));
      int idx = 3;
      if (c[idx].isNotEmpty && double.tryParse(c[idx]) == null) {
        lotId = lotIdByCode(skuId, c[idx]);
        idx++;
      }
      qty = double.parse(c[idx]);
      idx++;
      if (idx < c.length) uom = c[idx];
      status = 'AVAILABLE';
    } else if (current.docType == 'ADJ') {
      if (c.length < 3) throw Exception('cols');
      fromLocId = locIdByCode(c[0]);
      skuId = skuIdByCode(c[1]) ?? (throw Exception('sku'));
      int idx = 2;
      if (c[idx].isNotEmpty && double.tryParse(c[idx]) == null) {
        lotId = lotIdByCode(skuId, c[idx]);
        idx++;
      }
      qty = double.parse(c[idx]);
      idx++;
      if (idx < c.length) uom = c[idx];
      idx++;
      if (idx < c.length) status = c[idx].toUpperCase();
      idx++;
      if (idx < c.length) reason = c[idx];
    } else {
      // STATUS_MOVE
      if (c.length < 3) throw Exception('cols');
      fromLocId = locIdByCode(c[0]);
      skuId = skuIdByCode(c[1]) ?? (throw Exception('sku'));
      int idx = 2;
      if (c[idx].isNotEmpty && double.tryParse(c[idx]) == null) {
        lotId = lotIdByCode(skuId, c[idx]);
        idx++;
      }
      qty = double.parse(c[idx]);
      idx++;
      if (idx < c.length) uom = c[idx];
      idx++;
      if (idx < c.length) status = c[idx].toUpperCase();
      idx++;
      if (idx < c.length) toStatus = c[idx].toUpperCase();
      idx++;
      if (idx < c.length) reason = c[idx];
      toStatus ??= (status == 'AVAILABLE' ? 'HOLD' : 'AVAILABLE');
    }

    final manualLotAllowed = actor.isSupervisor;
    final finalLotId = (current.docType == 'OUT' && !manualLotAllowed) ? null : lotId;

    final sku = db.getSkus().firstWhere((s) => s.id == skuId);
    final qtyBase = db.convertToBaseOrThrow(sku, uom, qty);

    final line = DocumentLine(
      id: _uuid.v4(),
      skuId: skuId,
      lotId: finalLotId,
      fromLocationId: current.docType == 'IN' ? null : fromLocId,
      toLocationId: (current.docType == 'IN' || current.docType == 'TRF') ? toLocId : null,
      status: status,
      toStatus: current.docType == 'STATUS_MOVE' ? toStatus : null,
      uom: uom,
      qtyInput: qty,
      qtyBase: qtyBase,
      reasonCode: (current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') ? (reason ?? selectedReason) : null,
    );

    await db.addLine(actor, current.id, line);
  }

  Future<void> _saveAsTemplate(dynamic db) async {
    final current = doc;
    if (current == null) return;
    final nameCtrl = TextEditingController(text: '${current.docType}-${current.docNo}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Save as Template'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Template name', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      },
    );
    if (ok != true) return;
    final actor = ref.read(currentUserProvider);
    await db.saveTemplateFromDocument(actor: actor, docId: current.id, name: nameCtrl.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved')));
    }
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

            TextField(
              controller: scanCtrl,
              focusNode: scanFocus,
              decoration: const InputDecoration(
                labelText: 'Scan / paste (LOC:... SKU:... LOT:... QTY:...)',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (raw) {
                _applyScan(db, raw);
                scanCtrl.clear();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE')),
                      DropdownMenuItem(value: 'HOLD', child: Text('HOLD')),
                    ],
                    onChanged: (v) => setState(() => selectedStatus = v ?? 'AVAILABLE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: (current.docType == 'STATUS_MOVE')
                      ? DropdownButtonFormField<String>(
                          value: selectedToStatus,
                          decoration: const InputDecoration(
                            labelText: 'To Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE')),
                            DropdownMenuItem(value: 'HOLD', child: Text('HOLD')),
                          ],
                          onChanged: (v) => setState(() => selectedToStatus = v),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Auto-add on complete scan',
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch.adaptive(
                        value: autoAdd,
                        onChanged: (v) => setState(() => autoAdd = v),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openBulkPaste(db),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Bulk paste'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _saveAsTemplate(db),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Template'),
                ),
              ],
            ),
            const Divider(height: 22),

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

    final canSubmit = workflow && current.status == 'DRAFT';
    final canApprove = workflow && current.status == 'SUBMITTED' && actor.canApprove;
    final canPost = (workflow
            ? current.status == 'APPROVED'
            : (current.status == 'DRAFT' || current.status == 'APPROVED')) && actor.canPost;

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

            if (workflow) ...[
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
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Workflow OFF', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
              ),
              const SizedBox(width: 8),
            ],
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

    final enforcedStatus = (current.docType == 'OUT' || current.docType == 'TRF') ? 'AVAILABLE' : selectedStatus;
    final toStatus = current.docType == 'STATUS_MOVE' ? selectedToStatus : null;

    if (current.docType == 'STATUS_MOVE' && toStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('STATUS_MOVE requires To Status')));
      return;
    }

    final line = DocumentLine(
      id: _uuid.v4(),
      skuId: selectedSkuId!,
      lotId: lotId, // OUT staff => null => FEFO
      fromLocationId: (current.docType == 'IN') ? null : selectedFromLocId,
      toLocationId: (current.docType == 'IN' || current.docType == 'TRF') ? selectedToLocId : null,
      status: enforcedStatus,
      toStatus: toStatus,
      uom: selectedUom!,
      qtyInput: qtyInput,
      qtyBase: qtyBase,
      reasonCode: (current.docType == 'ADJ' || current.docType == 'STATUS_MOVE') ? selectedReason : null,
    );

    await db.addLine(actor, current.id, line);
    setState(() => doc = db.getDocument(current.id));
  }
}
