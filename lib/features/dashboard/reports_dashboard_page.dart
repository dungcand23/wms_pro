import 'package:flutter/material.dart';
import 'package:wms_pro/l10n/app_localizations.dart';

import '../../ui/widgets/section_title.dart';

class ReportsDashboardPage extends StatelessWidget {
  const ReportsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(t.reports, trailing: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('Export'))),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip('Date Range: Last 7 days'),
                _chip('Warehouse: VN_HCM01'),
                _chip('Status: AVAILABLE'),
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_alt_outlined), label: const Text('Apply')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Movement Trend (placeholder)', style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('TODO: chart inbound/outbound/transfer/adj by day'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Analysis Tables (placeholder)', style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('TODO: top SKU movement, top ADJ by reason, expiry aging'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F5FB),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE6E8F0)),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
