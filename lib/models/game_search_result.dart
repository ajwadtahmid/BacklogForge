/// A single result from the HowLongToBeat search endpoint.
class GameSearchResult {
  final String name;
  final String? artworkUrl;
  final double? essentialHours;
  final double? extendedHours;
  final double? completionistHours;

  const GameSearchResult({
    required this.name,
    this.artworkUrl,
    this.essentialHours,
    this.extendedHours,
    this.completionistHours,
  });
}
