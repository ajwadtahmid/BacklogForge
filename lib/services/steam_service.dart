import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/steam_game.dart';

/// Communicates with the Steam Web API to fetch user game libraries and profiles.
class SteamService {
  /// API key is embedded at build time and never exposed on device.
  static const _key = String.fromEnvironment('STEAM_API_KEY');
  static const _base = 'https://api.steampowered.com';

  Future<List<SteamGame>> getOwnedGames(String steamId) async {
    if (_key.isEmpty) {
      throw StateError(
        'STEAM_API_KEY missing — run with --dart-define-from-file=.env.json',
      );
    }

    final uri = Uri.parse(
      '$_base/IPlayerService/GetOwnedGames/v1/'
      '?key=$_key&steamid=$steamId'
      '&include_appinfo=true&include_played_free_games=true',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('steam_api_error');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final games = body['response']['games'] as List?;
    if (games == null) throw Exception('profile_private');

    return games
        .map((g) => SteamGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }
}
