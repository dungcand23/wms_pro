// lib/features/dashboard/ops_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class OpsDashboardPage extends ConsumerWidget {
  const OpsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(localDbProvider);

    final skus = db.getSkus();
    final balances = db.getBalances();
    final docs = db.getDocuments();

    final totalSku = skus.length;
    final totalQty = balances.fold<double>(0, (p, e) => p + ((e.qtyBase as num).toDouble()));
    final pendingApprove = docs.where((d) => d.status == 'SUBMITTED').length;
    final pendingPost = docs.where((d) => d.status == 'APPROVED').length;

    // ✅ SingleChildScrollView => không overflow trong test (h=524)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vận hành - Hôm nay',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiCard(context, title: 'Tổng SKU', value: '$totalSku'),
              _kpiCard(context, title: 'Tổng tồn (base)', value: totalQty.toStringAsFixed(3)),
              _kpiCard(context, title: 'Chờ duyệt', value: '$pendingApprove'),
              _kpiCard(context, title: 'Chờ post', value: '$pendingPost'),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'Chứng từ gần đây',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length > 10 ? 10 : docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i];
                return ListTile(
                  dense: true,
                  title: Text('${d.docNo} • ${d.docType}'),
                  subtitle: Text('status=${d.status} • updated=${d.updatedAtIso}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(BuildContext context, {required String title, required String value}) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
