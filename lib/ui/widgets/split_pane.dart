import 'package:flutter/material.dart';

class SplitPane extends StatefulWidget {
  final Widget left;
  final Widget center;
  final Widget right;

  const SplitPane({super.key, required this.left, required this.center, required this.right});

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  double leftW = 320;
  double rightW = 340;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        leftW = leftW.clamp(260, maxW * 0.4);
        rightW = rightW.clamp(280, maxW * 0.4);

        return Row(
          children: [
            SizedBox(width: leftW, child: widget.left),
            _divider(onDrag: (dx) => setState(() => leftW += dx)),
            Expanded(child: widget.center),
            _divider(onDrag: (dx) => setState(() => rightW -= dx)),
            SizedBox(width: rightW, child: widget.right),
          ],
        );
      },
    );
  }

  Widget _divider({required void Function(double dx) onDrag}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: Container(
        width: 10,
        alignment: Alignment.center,
        child: Container(width: 2, height: double.infinity, color: const Color(0xFFE6E8F0)),
      ),
    );
  }
}
