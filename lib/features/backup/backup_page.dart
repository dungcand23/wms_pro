import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  String? jsonText;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(localDbProvider);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Backup / Export dữ liệu (JSON)', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),

              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final s = await db.exportAllJson();
                      setState(() => jsonText = s);
                    },
                    child: const Text('Tạo JSON backup'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: jsonText == null
                        ? null
                        : () async {
                      await Clipboard.setData(ClipboardData(text: jsonText!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy JSON vào clipboard')));
                    },
                    child: const Text('Copy'),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E6F0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(jsonText ?? 'Bấm "Tạo JSON backup" để xuất dữ liệu.'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
