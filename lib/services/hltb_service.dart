import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_search_result.dart';
import '../models/time_to_beat.dart';

/// Communicates with the self-hosted HowLongToBeat proxy on Render.
/// The proxy wraps the howlongtobeatpy Python library so the app stays
/// cross-platform without any native dependencies.
class HltbService {
  static const _baseUrl = 'https://backlogforge.onrender.com';
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

    final sanitized = _sanitize(gameName);
    if (sanitized == gameName) return null;
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
    );
  }

  /// Strips trademark/copyright symbols and other non-ASCII characters that
  /// HLTB typically omits from their titles (e.g. ® → '', ™ → '').
  String _sanitize(String name) {
    return name
        .replaceAll(RegExp(r'[®™©]'), '')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
