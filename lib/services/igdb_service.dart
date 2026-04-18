import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching game completion time data from the IGDB API via Twitch OAuth.
/// Handles token management and rate-limited requests to IGDB endpoints.
class IgdbService {
  static const _twitchTokenUrl = 'https://id.twitch.tv/oauth2/token';
  static const _igdbBase = 'https://api.igdb.com/v4';
  static const _clientId = String.fromEnvironment('TWITCH_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('TWITCH_CLIENT_SECRET');

  String? _accessToken;
  DateTime? _tokenExpiry;

  Future<void> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    final res = await http.post(
      Uri.parse(
        '$_twitchTokenUrl'
        '?client_id=$_clientId'
        '&client_secret=$_clientSecret'
        '&grant_type=client_credentials',
      ),
    );

    if (res.statusCode != 200) {
      throw Exception('Twitch OAuth failed (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int;
    // Refresh 5 minutes early to avoid edge-case expiry mid-request.
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
  }

  Map<String, String> get _headers => {
        'Client-ID': _clientId,
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'text/plain',
      };

  /// Searches IGDB for a game by name and returns completion time data.
  Future<TimeToBeat?> lookup(String gameName) async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      throw StateError(
        'TWITCH_CLIENT_ID / TWITCH_CLIENT_SECRET missing — '
        'run with --dart-define-from-file=.env.json',
      );
    }

    await _ensureToken();

    // Step 1: Search for the game to get its IGDB ID.
    final searchRes = await http.post(
      Uri.parse('$_igdbBase/games'),
      headers: _headers,
      body: 'search "$gameName"; fields id, name; limit 1;',
    );

    if (searchRes.statusCode != 200) {
      throw Exception('IGDB search failed (${searchRes.statusCode})');
    }

    final games = jsonDecode(searchRes.body) as List;
    if (games.isEmpty) return null;

    final gameId = games.first['id'] as int;

    // Step 2: Fetch time-to-beat data for this game.
    final ttbRes = await http.post(
      Uri.parse('$_igdbBase/game_time_to_beats'),
      headers: _headers,
      body: 'where game_id = $gameId; fields hastily, normally, completely;',
    );

    if (ttbRes.statusCode != 200) {
      throw Exception('IGDB time_to_beat failed (${ttbRes.statusCode})');
    }

    final ttbList = jsonDecode(ttbRes.body) as List;
    if (ttbList.isEmpty) return null;

    final ttb = ttbList.first as Map<String, dynamic>;
    return TimeToBeat(
      rushedHours: _secondsToHours(ttb['hastily']),
      casuallyHours: _secondsToHours(ttb['normally']),
      completionistHours: _secondsToHours(ttb['completely']),
    );
  }

  double? _secondsToHours(dynamic seconds) {
    if (seconds == null || seconds == 0) return null;
    return (seconds as int) / 3600;
  }
}

class TimeToBeat {
  final double? rushedHours;
  final double? casuallyHours;
  final double? completionistHours;

  TimeToBeat({this.rushedHours, this.casuallyHours, this.completionistHours});
}
