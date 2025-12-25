import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? sub;
  const KpiCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  if (sub != null) ...[
                    const SizedBox(height: 4),
                    Text(sub!, style: const TextStyle(color: Colors.black54)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
