String lineBadgeLabel(String lineName) {
  final normalized = lineName.trim();

  if (normalized.contains('경의중앙')) {
    return '경중';
  }

  final match = RegExp(r'\d+').firstMatch(normalized);
  if (match != null) {
    return match.group(0)!;
  }

  if (normalized.isEmpty) {
    return '';
  }

  return normalized.length > 2 ? normalized.substring(0, 2) : normalized;
}
