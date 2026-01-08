class ScanResult {
  final String type; // LOC/SKU/LOT/QTY/UOM/STATUS/FROM/TO
  final String value;
  const ScanResult(this.type, this.value);
}

ScanResult? parseScan(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // allow both "LOC:xxx" and "loc:xxx"
  final upper = s.toUpperCase();

  if (upper.startsWith('LOC:')) return ScanResult('LOC', s.substring(4).trim());
  if (upper.startsWith('FROM:')) return ScanResult('FROM', s.substring(5).trim());
  if (upper.startsWith('TO:')) return ScanResult('TO', s.substring(3).trim());
  if (upper.startsWith('SKU:')) return ScanResult('SKU', s.substring(4).trim());
  if (upper.startsWith('LOT:')) return ScanResult('LOT', s.substring(4).trim());
  if (upper.startsWith('QTY:')) return ScanResult('QTY', s.substring(4).trim());
  if (upper.startsWith('UOM:')) return ScanResult('UOM', s.substring(4).trim());
  if (upper.startsWith('STATUS:')) return ScanResult('STATUS', s.substring(7).trim());

  // fallback: if no prefix -> treat as SKU for speed (tuỳ bạn)
  return ScanResult('SKU', s);
}

/// Parse a scan line that may contain multiple tokens, e.g.
/// "LOC:KH01-A01 SKU:ACME1001 LOT:BATCH202301 QTY:10 UOM:PCS"
List<ScanResult> parseScanLine(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  // split by whitespace but keep tokens like "LOC:..."
  final parts = trimmed.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty);
  final out = <ScanResult>[];
  for (final p in parts) {
    final r = parseScan(p);
    if (r != null) out.add(r);
  }
  return out;
}
