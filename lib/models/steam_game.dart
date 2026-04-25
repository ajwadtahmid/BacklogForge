/// Returns the Steam CDN header image URL for the given [appId].
String steamArtworkUrl(int appId) =>
    'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';

/// Represents a single game from the Steam GetOwnedGames API response.
class SteamGame {
  final int appId;
  final String name;
  final int playtimeMinutes;
  final DateTime? lastPlayedAt;

  SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    this.lastPlayedAt,
  });

  factory SteamGame.fromJson(Map<String, dynamic> j) {
    // Steam occasionally returns numeric fields as doubles in some API versions;
    // casting via num avoids a runtime TypeError if the type is not exactly int.
    final rtime = (j['rtime_last_played'] as num?)?.toInt();
    return SteamGame(
      appId: (j['appid'] as num).toInt(),
      name: j['name'] as String,
      playtimeMinutes: (j['playtime_forever'] as num?)?.toInt() ?? 0,
      // Steam returns 0 for rtime_last_played when a game has never been launched.
      lastPlayedAt: (rtime != null && rtime > 0)
          ? DateTime.fromMillisecondsSinceEpoch(rtime * 1000)
          : null,
    );
  }

  String get artworkUrl => steamArtworkUrl(appId);
}
