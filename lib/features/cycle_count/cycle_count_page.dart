// lib/features/cycle_count/cycle_count_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/models/document.dart';

class CycleCountPage extends ConsumerStatefulWidget {
  const CycleCountPage({super.key});

  @override
  ConsumerState<CycleCountPage> createState() => _CycleCountPageState();
}

class _CycleCountPageState extends ConsumerState<CycleCountPage> {
  final _uuid = const Uuid();

  String? locId;
  String? skuId;
  String? lotId;
  String status = 'AVAILABLE';

  final countedCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    countedCtrl.dispose();
    super.dispose();
  }

  double _getCurrentQty(dynamic db, String? locId, String? skuId, String? lotId, String status) {
    if (locId == null || skuId == null || lotId == null) return 0;

    final balances = db.getBalances();
    for (final b in balances) {
      if (b.locationId == locId && b.skuId == skuId && b.lotId == lotId && b.status == status) {
        return (b.qtyBase as num).toDouble();
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(localDbProvider);
    final actor = ref.watch(currentUserProvider);
    final wh = ref.watch(warehouseProvider);

    final locs = db.getLocations(warehouseCode: wh);
    final skus = db.getSkus();

    // init selection (safe)
    if (locId == null && locs.isNotEmpty) locId = locs.first.id;
    if (skuId == null && skus.isNotEmpty) skuId = skus.first.id;

    final lots = skuId == null ? const [] : db.getLots(skuId: skuId);

    if (lotId == null && lots.isNotEmpty) lotId = lots.first.id;
    if (lots.isEmpty) lotId = null;

    final currentQty = _getCurrentQty(db, locId, skuId, lotId, status);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cycle Count (Kiểm kê → sinh ADJ)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: locId,
                items: locs
                    .map((e) => DropdownMenuItem<String>(
                  value: e.id,
                  child: Text(e.code),
                ))
                    .toList(),
                onChanged: (v) => setState(() => locId = v),
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: skuId,
                items: skus
                    .map((e) => DropdownMenuItem<String>(
                  value: e.id,
                  child: Text(e.code),
                ))
                    .toList(),
                onChanged: (v) => setState(() {
                  skuId = v;
                  // đổi SKU => reset lot
                  final newLots = db.getLots(skuId: skuId);
                  lotId = newLots.isNotEmpty ? newLots.first.id : null;
                }),
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: lotId,
                items: lots
                    .map((e) => DropdownMenuItem<String>(
                  value: e.id,
                  child: Text(e.lotCode),
                ))
                    .toList(),
                onChanged: (v) => setState(() => lotId = v),
                decoration: const InputDecoration(
                  labelText: 'Lot',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: status,
                items: const [
                  DropdownMenuItem<String>(value: 'AVAILABLE', child: Text('AVAILABLE')),
                  DropdownMenuItem<String>(value: 'HOLD', child: Text('HOLD')),
                ],
                onChanged: (v) => setState(() => status = v ?? 'AVAILABLE'),
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'Tồn hiện tại: $currentQty (base)',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: countedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số đếm thực tế (base qty)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (locId == null || skuId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thiếu Location hoặc SKU')),
                        );
                        return;
                      }
                      if (lotId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SKU này chưa có Lot. Hãy tạo Lot trước.')),
                        );
                        return;
                      }

                      final counted = double.tryParse(countedCtrl.text.trim()) ?? 0;
                      final delta = counted - currentQty;

                      if (delta == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Không có chênh lệch.')),
                        );
                        return;
                      }

                      final doc = await db.createNewDocument(
                        actor: actor,
                        docType: 'ADJ',
                        warehouseCode: wh,
                      );

                      final line = DocumentLine(
                        id: _uuid.v4(),
                        skuId: skuId!,
                        lotId: lotId!,
                        fromLocationId: locId,
                        toLocationId: null,
                        status: status,
                        toStatus: null,
                        uom: 'BASE',
                        qtyInput: delta,
                        qtyBase: delta,
                        reasonCode: 'COUNT', // ✅ bắt buộc cho ADJ
                      );

                      await db.addLine(actor, doc.id, line);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã tạo ADJ ${doc.docNo} (delta=$delta). Vào Chứng từ để SUBMIT/APPROVE/POST',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Tạo phiếu ADJ từ kiểm kê'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
