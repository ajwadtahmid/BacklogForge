import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/steam_game.dart';
import 'api_config.dart';
import 'app_logger.dart';
import 'sync_exception.dart';

/// Communicates with the BacklogForge backend to fetch user game libraries.
/// The backend handles all Steam API calls securely.
class SteamService {
  static final _backendUrl = ApiConfig.backendUrl;
  static final _headers = ApiConfig.clientToken.isNotEmpty
      ? {'X-Client-Token': ApiConfig.clientToken}
      : const <String, String>{};
  // Extra headroom to accommodate Render free-tier cold starts (~30 s spin-up).
  static const _timeout = AppConstants.kSteamTimeout;

  // Steam64 IDs are 17-digit numbers starting with 7656119.
  static final _steam64Pattern = RegExp(r'^7656119\d{10}$');

  static void _validateSteamId(String steamId) {
    if (!_steam64Pattern.hasMatch(steamId)) {
      throw ArgumentError('Invalid Steam64 ID: $steamId');
    }
  }

  /// Fetches the user's owned games from the backend.
  /// The backend securely calls the Steam API using STEAM_API_KEY.
  Future<List<SteamGame>> getOwnedGames(String steamId) async {
    _validateSteamId(steamId);
    final uri = Uri.parse('$_backendUrl/user/library')
        .replace(queryParameters: {'steam_id': steamId});

    try {
      final res = await http.get(uri, headers: _headers).timeout(_timeout);

      if (res.statusCode == 403) throw const ProfilePrivateException();
      if (res.statusCode != 200) {
        AppLogger.instance.error('Backend /user/library returned ${res.statusCode}: ${res.body}');
        throw const SteamApiException();
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        throw const SteamApiException();
      }
      if (decoded is! List) throw const SteamApiException();
      return decoded
          .map((g) => SteamGame.fromJson(g as Map<String, dynamic>))
          .toList();
    } on SyncException {
      rethrow;
    } on TimeoutException {
      throw const ServerTimeoutException();
    } on SocketException {
      throw const NetworkException();
    }
  }

  /// Fetches a single game's playtime by [appId].
  /// Passes appids_filter to the backend so only one game is returned,
  /// avoiding the full-library download.
  Future<int?> getGamePlaytime(String steamId, int appId) async {
    _validateSteamId(steamId);
    final uri = Uri.parse('$_backendUrl/user/library').replace(
      queryParameters: {'steam_id': steamId, 'app_id': appId.toString()},
    );
    try {
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 403) throw const ProfilePrivateException();
      if (res.statusCode != 200) throw const SteamApiException();
      final dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        throw const SteamApiException();
      }
      if (decoded is! List) throw const SteamApiException();
      if (decoded.isEmpty) return null;
      final game = SteamGame.fromJson(decoded.first as Map<String, dynamic>);
      return game.playtimeMinutes;
    } on SyncException {
      rethrow;
    } on TimeoutException {
      throw const ServerTimeoutException();
    } on SocketException {
      throw const NetworkException();
    }
  }
}
