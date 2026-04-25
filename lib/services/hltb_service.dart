import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_search_result.dart';
import '../models/time_to_beat.dart';
import 'api_config.dart';

/// Communicates with the self-hosted HowLongToBeat proxy on Render.
/// The proxy wraps the howlongtobeatpy Python library so the app stays
/// cross-platform without any native dependencies.
class HltbService {
  static const _baseUrl = ApiConfig.backendUrl;
  static const _timeout = Duration(seconds: 15);

  /// Returns up to [limit] search results matching [query].
  Future<List<GameSearchResult>> search(String query, {int limit = 10}) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/search').replace(
            queryParameters: {'q': query, 'limit': '$limit'},
          ),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('HLTB search failed (${res.statusCode})');
    }

    final list = jsonDecode(res.body) as List;
    return list
        .map(
          (item) => GameSearchResult(
            name: item['name'] as String,
            artworkUrl: item['image_url'] as String?,
            essentialHours: (item['essential_hours'] as num?)?.toDouble(),
            extendedHours: (item['extended_hours'] as num?)?.toDouble(),
            completionistHours:
                (item['completionist_hours'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  /// Returns the best-matching time-to-beat data for [gameName],
  /// or null if no confident match is found.
  ///
  /// If the first lookup returns nothing (e.g. Steam name contains ® or ™
  /// that HLTB omits), retries automatically with special characters stripped.
  Future<TimeToBeat?> lookup(String gameName) async {
    final result = await _lookupRaw(gameName);
    if (result != null) return result;

    final sanitized = normalise(gameName);
    if (sanitized == gameName.toLowerCase()) return null;
    return _lookupRaw(sanitized);
  }

  Future<TimeToBeat?> _lookupRaw(String gameName) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/lookup').replace(
            queryParameters: {'q': gameName},
          ),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('HLTB lookup failed (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    if (body == null) return null;

    return TimeToBeat(
      essentialHours: (body['essential_hours'] as num?)?.toDouble(),
      extendedHours: (body['extended_hours'] as num?)?.toDouble(),
      completionistHours: (body['completionist_hours'] as num?)?.toDouble(),
      hltbName: body['name'] as String?,
    );
  }

  /// Normalises a game name for HLTB lookup/search:
  /// strips trademark/copyright symbols, removes special characters,
  /// collapses whitespace, and lowercases.
  ///
  /// Used both as the retry fallback in [lookup] and as the pre-fill
  /// query in the HLTB update screen.
  static String normalise(String name) {
    return name
        .replaceAll(RegExp(r'[™®©℠]'), '')
        .replaceAll(RegExp(r'\(r\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(tm\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim()
        .toLowerCase();
  }
}
