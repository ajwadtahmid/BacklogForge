import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/steam_game.dart';

/// Communicates with the BacklogForge backend to fetch user game libraries.
/// The backend handles all Steam API calls securely.
class SteamService {
  static const _backendUrl = 'https://backlogforge.onrender.com';
  static const _timeout = Duration(seconds: 15);

  /// Fetches the user's owned games from the backend.
  /// The backend securely calls the Steam API using STEAM_API_KEY.
  Future<List<SteamGame>> getOwnedGames(String steamId) async {
    final uri = Uri.parse('$_backendUrl/user/library')
        .replace(queryParameters: {'steam_id': steamId});

    final res = await http.get(uri).timeout(_timeout);

    if (res.statusCode == 403) {
      throw Exception('profile_private');
    }
    if (res.statusCode != 200) {
      throw Exception('steam_api_error');
    }

    final games = jsonDecode(res.body) as List;
    return games
        .map((g) => SteamGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }
}
