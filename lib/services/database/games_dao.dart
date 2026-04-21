import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'app_database.dart';
import 'tables.dart';
import '../hltb_service.dart';
import '../status_calculator.dart';
import '../../models/time_to_beat.dart';

part 'games_dao.g.dart';

/// Sort options available in the backlog and completed tabs.
enum SortMode { alphabetical, shortest, longest, mostPlayed, neglected }

@DriftAccessor(tables: [Games])
class GamesDao extends DatabaseAccessor<AppDatabase> with _$GamesDaoMixin {
  GamesDao(super.db);

  final _hltb = HltbService();

  /// Finds a Steam game by its [appId] for a specific user.
  Future<Game?> findByAppId(int appId, String steamId) =>
      (select(games)
            ..where((g) => g.appId.equals(appId) & g.steamId.equals(steamId)))
          .getSingleOrNull();

  /// Finds a game by name for a specific user (used to detect duplicates before manual add).
  Future<Game?> findByName(String name, String steamId) =>
      (select(games)
            ..where((g) => g.name.equals(name) & g.steamId.equals(steamId)))
          .getSingleOrNull();

  /// Returns every game in the library for a user, regardless of status.
  Future<List<Game>> getAllGames(String steamId) =>
      (select(games)..where((g) => g.steamId.equals(steamId))).get();

  /// Backlog tab: actively-playing games (without a completedAt) pinned to top,
  /// then unstarted backlog alphabetically. Excludes completed games that are
  /// marked playing — those stay in the completed tab.
  Future<List<Game>> getBacklog(String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('backlog') |
                  (g.status.equals('playing') & g.completedAt.isNull())))
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            (g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Completed tab: finished games, plus any completed game the user is
  /// currently re-playing (status='playing', completedAt IS NOT NULL).
  Future<List<Game>> getCompleted(String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('completed') |
                  (g.status.equals('playing') & g.completedAt.isNotNull())))
          ..orderBy([
            (g) => OrderingTerm(
              expression: g.completedAt,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
          ]))
        .get();
  }

  Stream<List<Game>> watchBacklog(String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('backlog') |
                  (g.status.equals('playing') & g.completedAt.isNull()))))
        .watch();
  }

  /// Fetches time-to-beat data from HLTB for any game that doesn't have it yet.
  /// Returns the number of games that received new data.
  Future<int> fetchAllTimeToBeat(List<Game> allGames) async {
    int fetched = 0;
    for (final g in allGames) {
      if (g.manualOverride ||
          g.essentialHours != null ||
          g.extendedHours != null ||
          g.completionistHours != null) {
        continue;
      }
      try {
        final data = await _hltb.lookup(g.name);
        if (data != null) {
          fetched++;
          await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id)))
              .write(
            GamesCompanion(
              essentialHours: Value(data.essentialHours),
              extendedHours: Value(data.extendedHours),
              completionistHours: Value(data.completionistHours),
            ),
          );
        }
      } catch (e) {
        debugPrint('HLTB lookup failed for "${g.name}": $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return fetched;
  }

  /// Re-derives the status for every non-overridden game based on current playtime
  /// and the user's chosen completion threshold.
  Future<void> recalculateAllStatuses(String steamId) async {
    final allGames = await getAllGames(steamId);

    final settings = await (db.select(db.appSettings)
          ..where((s) => s.steamId.equals(steamId)))
        .getSingleOrNull();
    final thresholdStr = settings?.completionThreshold ?? 'essential';
    final threshold = _parseThreshold(thresholdStr);

    await db.transaction(() async {
      for (final game in allGames) {
        if (game.manualOverride) continue;
        final newStatus = calculateStatus(game, threshold);
        await (db.update(db.games)..where((g) => g.id.equals(game.id))).write(
          GamesCompanion(status: Value(newStatus.name)),
        );
      }
    });
  }

  /// Inserts a manually-searched game with a negative appId (to distinguish it
  /// from Steam games) and optional HLTB time-to-beat data.
  Future<int> addManualGame(
      String gameName, TimeToBeat? timeToBeat, String steamId,
      {String? artworkUrl}) {
    // Negative millisecond timestamp gives a unique ID that won't collide with Steam appIds.
    final negativeId = -DateTime.now().millisecondsSinceEpoch;
    return into(games).insert(
      GamesCompanion.insert(
        steamId: steamId,
        appId: negativeId,
        name: gameName,
        playtimeMinutes: const Value(0),
        essentialHours: Value(timeToBeat?.essentialHours),
        extendedHours: Value(timeToBeat?.extendedHours),
        completionistHours: Value(timeToBeat?.completionistHours),
        hltbImageUrl: Value(artworkUrl),
        manualOverride: const Value(true),
        addedAt: DateTime.now(),
      ),
    );
  }

  /// Maps legacy threshold string values (from older schema versions or settings)
  /// to the current [CompletionThreshold] enum. Defaults to essential.
  CompletionThreshold _parseThreshold(String value) {
    const legacy = {
      'main': CompletionThreshold.essential,
      'mainPlusExtras': CompletionThreshold.extended,
      'casually': CompletionThreshold.extended,
      'extended': CompletionThreshold.extended,
    };
    return legacy[value] ??
        CompletionThreshold.values.asNameMap()[value] ??
        CompletionThreshold.essential;
  }

  List<OrderClauseGenerator<$GamesTable>> _orderFor(SortMode mode) {
    switch (mode) {
      case SortMode.alphabetical:
        return [
          (g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc)
        ];
      case SortMode.shortest:
        return [
          (g) => OrderingTerm(
              expression: g.extendedHours.isNull(), mode: OrderingMode.asc),
          (g) => OrderingTerm.asc(g.extendedHours),
        ];
      case SortMode.longest:
        return [
          (g) => OrderingTerm(
              expression: g.extendedHours.isNull(), mode: OrderingMode.asc),
          (g) => OrderingTerm.desc(g.extendedHours),
        ];
      case SortMode.mostPlayed:
        return [(g) => OrderingTerm.desc(g.playtimeMinutes)];
      case SortMode.neglected:
        return [(g) => OrderingTerm.asc(g.addedAt)];
    }
  }

  /// Backlog games sorted by [mode]. Neglected mode additionally filters to
  /// games with zero playtime. Excludes completed games being re-played.
  Future<List<Game>> backlogSorted(SortMode mode, String steamId) {
    return (select(games)
          ..where((g) {
            final isBacklog = g.steamId.equals(steamId) &
                (g.status.equals('backlog') |
                    (g.status.equals('playing') & g.completedAt.isNull()));
            return mode == SortMode.neglected
                ? isBacklog & g.playtimeMinutes.equals(0)
                : isBacklog;
          })
          ..orderBy(_orderFor(mode)))
        .get();
  }

  /// Completed games sorted by [mode], including completed games being re-played.
  Future<List<Game>> completedSorted(SortMode mode, String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('completed') |
                  (g.status.equals('playing') & g.completedAt.isNotNull())))
          ..orderBy(_orderFor(mode)))
        .get();
  }
}
