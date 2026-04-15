class SteamGame {
  final int appId;
  final String name;
  final int playtimeMinutes;

  SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
  });

  factory SteamGame.fromJson(Map<String, dynamic> j) => SteamGame(
    appId: j['appid'] as int,
    name: j['name'] as String,
    playtimeMinutes: j['playtime_forever'] as int,
  );

  /// Returns the CDN URL for the game's header image from Steam.
  String get artworkUrl =>
      'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';
}
