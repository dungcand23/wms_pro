import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class TransportPage extends ConsumerStatefulWidget {
  const TransportPage({super.key});

  @override
  ConsumerState<TransportPage> createState() => _TransportPageState();
}

class _TransportPageState extends ConsumerState<TransportPage> {
  bool showForm = true;

  final aCtrl = TextEditingController();
  final bCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ✅ Tự thu gọn sidebar khi vào màn Vận tải để map rộng hơn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sidebarCollapsedProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    // Trả sidebar về bình thường khi rời màn (nếu bạn muốn giữ collapsed luôn thì bỏ dòng này)
    ref.read(sidebarCollapsedProvider.notifier).state = false;
    aCtrl.dispose();
    bCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 1100;

        return Row(
          children: [
            if (showForm)
              SizedBox(
                width: isNarrow ? 360 : 420,
                child: _FormPanel(
                  aCtrl: aCtrl,
                  bCtrl: bCtrl,
                  onCollapse: () => setState(() => showForm = false),
                ),
              ),
            Expanded(
              child: _MapCanvas(
                onExpandForm: () => setState(() => showForm = true),
                isFormHidden: !showForm,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FormPanel extends StatelessWidget {
  final TextEditingController aCtrl;
  final TextEditingController bCtrl;
  final VoidCallback onCollapse;

  const _FormPanel({
    required this.aCtrl,
    required this.bCtrl,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E6F0))),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Điểm đi / đến',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Thu gọn form',
                  onPressed: onCollapse,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _StopRow(
                  label: 'A',
                  controller: aCtrl,
                  hint: 'Nhập điểm A',
                ),
                const SizedBox(height: 10),
                _StopRow(
                  label: 'B',
                  controller: bCtrl,
                  hint: 'Nhập điểm B',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm điểm dừng'),
                ),
                const SizedBox(height: 14),

                const _BlockTitle('Tuyến đường'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Route'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Xóa tuyến'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const _BlockTitle('Gợi ý phương tiện'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(label: const Text('Van / Ô tô'), selected: true, onSelected: (_) {}),
                    ChoiceChip(label: const Text('Xe tải'), selected: false, onSelected: (_) {}),
                    ChoiceChip(label: const Text('Xe máy'), selected: false, onSelected: (_) {}),
                  ],
                ),
                const SizedBox(height: 14),

                const _BlockTitle('Chế độ bản đồ'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(label: const Text('Thường'), selected: true, onSelected: (_) {}),
                    ChoiceChip(label: const Text('Vệ tinh'), selected: false, onSelected: (_) {}),
                    ChoiceChip(label: const Text('Địa hình'), selected: false, onSelected: (_) {}),
                    FilterChip(label: const Text('Traffic'), selected: true, onSelected: (_) {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _StopRow({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: () => controller.clear(), icon: const Icon(Icons.close)),
      ],
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w900));
  }
}

class _MapCanvas extends StatelessWidget {
  final VoidCallback onExpandForm;
  final bool isFormHidden;

  const _MapCanvas({
    required this.onExpandForm,
    required this.isFormHidden,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Placeholder map (Phase sau sẽ nhúng HERE/MapLibre/Google…)
        Container(
          color: const Color(0xFFE9EEF7),
          child: const Center(
            child: Text(
              'MAP CANVAS\n(Phase 4: nhúng HERE JS / routing / polyline)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),

        if (isFormHidden)
          Positioned(
            left: 12,
            top: 12,
            child: ElevatedButton.icon(
              onPressed: onExpandForm,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Mở form'),
            ),
          ),
      ],
    );
  }
}
