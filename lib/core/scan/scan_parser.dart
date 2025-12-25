class ScanResult {
  final String type; // LOC/SKU/LOT
  final String value;
  const ScanResult(this.type, this.value);
}

ScanResult? parseScan(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // allow both "LOC:xxx" and "loc:xxx"
  final upper = s.toUpperCase();

  if (upper.startsWith('LOC:')) return ScanResult('LOC', s.substring(4).trim());
  if (upper.startsWith('SKU:')) return ScanResult('SKU', s.substring(4).trim());
  if (upper.startsWith('LOT:')) return ScanResult('LOT', s.substring(4).trim());

  // fallback: if no prefix -> treat as SKU for speed (tuỳ bạn)
  return ScanResult('SKU', s);
}
