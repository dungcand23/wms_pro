import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/models/audit.dart';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(localDbProvider);

    final items = db.auditBox.values
        .map((s) => AuditEntry.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.tsIso.compareTo(a.tsIso));

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Card(
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final a = items[i];
            return ListTile(
              title: Text(
                '${a.action} • ${a.entityType} • ${a.entityId}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${a.tsIso}\nactor=${a.actor}'
                    '${a.reason != null ? ' • reason=${a.reason}' : ''}'
                    '\nchanged=${a.changedFields.join(', ')}',
              ),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }
}
