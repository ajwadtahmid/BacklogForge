/// Returns true if [name] matches [query] using a two-pass strategy:
///   1. Direct substring match (case-insensitive).
///   2. Punctuation-stripped match — handles "Witcher3" → "The Witcher 3".
bool matchesGameName(String name, String query) {
  final lower = name.toLowerCase();
  if (lower.contains(query)) return true;
  final stripped = lower.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  final qStripped = query.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  return qStripped.isNotEmpty && stripped.contains(qStripped);
}
