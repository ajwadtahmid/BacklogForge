import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'database/app_database.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import 'app_logger.dart';

class ExportImportService {
  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  static String buildFilename() => 'backlogforge_export_${_dateStamp()}.json';

  /// Builds the export JSON string without touching the filesystem.
  static String buildExportJson(String steamId, List<Game> games) {
    final now = DateTime.now();
    final payload = {
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'steamId': steamId,
      'games': games
          .map((g) => {
                'appId': g.appId,
                'name': g.name,
                'playtimeMinutes': g.playtimeMinutes,
                'status': g.status,
                'essentialHours': g.essentialHours,
                'extendedHours': g.extendedHours,
                'completionistHours': g.completionistHours,
                'hltbName': g.hltbName,
                'hltbImageUrl': g.hltbImageUrl,
                'playStyle': g.playStyle,
                'manualOverride': g.manualOverride,
                'addedAt': g.addedAt.toIso8601String(),
                'completedAt': g.completedAt?.toIso8601String(),
                'lastPlayedAt': g.lastPlayedAt?.toIso8601String(),
                'notes': g.notes,
                'rating': g.rating,
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Writes [json] to [path]. Used on macOS/Windows/Linux after the
  /// save-dialog returns a path.
  static Future<void> writeToPath(String path, String json) =>
      File(path).writeAsString(json);

  static Future<List<GamesCompanion>> parseImportFile(String path) =>
      File(path).readAsString().then(parseImportJson);

  static List<GamesCompanion> parseImportBytes(Uint8List bytes) =>
      parseImportJson(utf8.decode(bytes));

  /// Returns the steamId stored in the export file, or null if absent/invalid.
  static String? readBackupSteamId(String content) {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['steamId'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String buildCsvFilename() => 'backlogforge_export_${_dateStamp()}.csv';

  /// Builds a CSV export string with one row per game.
  static String buildExportCsv(String steamId, List<Game> games) {
    final buffer = StringBuffer();
    buffer.writeln('Name,Status,Playtime (h),Rating,HLTB Name,Essential (h),Extended (h),Completionist (h),Completed At,Notes');
    for (final g in games) {
      buffer.writeln([
        _csvField(g.name),
        g.status,
        (g.playtimeMinutes / 60.0).toStringAsFixed(2),
        g.rating?.toString() ?? '',
        _csvField(g.hltbName ?? ''),
        g.essentialHours?.toStringAsFixed(1) ?? '',
        g.extendedHours?.toStringAsFixed(1) ?? '',
        g.completionistHours?.toStringAsFixed(1) ?? '',
        g.completedAt?.toIso8601String() ?? '',
        _csvField(g.notes ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Parses a JSON export string produced by [buildExportJson].
  static List<GamesCompanion> parseImportJson(String content) {
    final data = jsonDecode(content) as Map<String, dynamic>;

    final version = data['version'] as int?;
    if (version != 1) throw const FormatException('Unsupported export version');

    final gamesJson = data['games'] as List<dynamic>;
    final validStatuses = GameStatus.values.asNameMap().keys.toSet();
    final validPlayStyles = PlayStyle.values.asNameMap().keys.toSet();

    return gamesJson.map<GamesCompanion?>((raw) {
      try {
        final g = raw as Map<String, dynamic>;

        final rawStatus = g['status'] as String?;
        final status = rawStatus != null && validStatuses.contains(rawStatus)
            ? rawStatus
            : GameStatus.backlog.name;

        final rawPlayStyle = g['playStyle'] as String?;
        final playStyle =
            rawPlayStyle != null && validPlayStyles.contains(rawPlayStyle)
                ? rawPlayStyle
                : null;

        return GamesCompanion(
          appId: Value(g['appId'] as int),
          name: Value(g['name'] as String),
          playtimeMinutes: Value((g['playtimeMinutes'] as num?)?.toInt() ?? 0),
          status: Value(status),
          essentialHours: Value((g['essentialHours'] as num?)?.toDouble()),
          extendedHours: Value((g['extendedHours'] as num?)?.toDouble()),
          completionistHours:
              Value((g['completionistHours'] as num?)?.toDouble()),
          hltbName: Value(g['hltbName'] as String?),
          hltbImageUrl: Value(g['hltbImageUrl'] as String?),
          playStyle: Value(playStyle),
          manualOverride: Value(g['manualOverride'] as bool? ?? false),
          addedAt: Value(DateTime.parse(g['addedAt'] as String)),
          completedAt: Value(g['completedAt'] != null
              ? DateTime.parse(g['completedAt'] as String)
              : null),
          lastPlayedAt: Value(g['lastPlayedAt'] != null
              ? DateTime.parse(g['lastPlayedAt'] as String)
              : null),
          notes: Value(g['notes'] as String?),
          rating: Value((g['rating'] as num?)?.toInt()),
        );
      } catch (e) {
        AppLogger.instance.warning('Skipped malformed game entry during import: $e');
        return null;
      }
    }).whereType<GamesCompanion>().toList();
  }
}
