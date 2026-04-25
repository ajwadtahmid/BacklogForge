import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';
import '../hltb_service.dart';
import '../status_calculator.dart';
import '../app_logger.dart';
import '../../models/time_to_beat.dart';
import '../../models/game_status.dart';

part 'games_dao.g.dart';

/// Sort options available in the backlog and completed tabs.
enum SortMode { alphabetical, progress, shortest, longest, mostPlayed, neglected }

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
  /// Re-playing games are pinned to the top.
  Future<List<Game>> getCompleted(String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('completed') |
                  (g.status.equals('playing') & g.completedAt.isNotNull())))
          ..orderBy([
            // 'playing' > 'completed' alphabetically — DESC pins re-playing games.
            (g) => OrderingTerm.desc(g.status),
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
  /// Requests are sequential with a 300ms gap between each to avoid rate-limiting
  /// the HLTB scraper on the backend.
  /// [onProgress] is called after each game is processed with (current, total).
  /// Returns a record with [fetched] (games that received data) and [failed]
  /// (games where the lookup threw a network/server error, excluding no-match).
  Future<({int fetched, int failed})> fetchAllTimeToBeat(
    List<Game> allGames, {
    void Function(int current, int total)? onProgress,
  }) async {
    final toFetch = allGames
        .where((g) =>
            !g.manualOverride &&
            g.essentialHours == null &&
            g.extendedHours == null &&
            g.completionistHours == null)
        .toList();

    int fetched = 0;
    int failed = 0;

    for (int i = 0; i < toFetch.length; i++) {
      final g = toFetch[i];
      TimeToBeat? data;
      try {
        data = await _hltb.lookup(g.name);
      } catch (e) {
        failed++;
        AppLogger.instance.warning('HLTB lookup failed for "${g.name}"', e);
      }
      if (data != null) {
        fetched++;
        await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id)))
            .write(GamesCompanion(
          essentialHours: Value(data.essentialHours),
          extendedHours: Value(data.extendedHours),
          completionistHours: Value(data.completionistHours),
          hltbName: Value(data.hltbName),
        ));
      }
      onProgress?.call(i + 1, toFetch.length);
      if (i < toFetch.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return (fetched: fetched, failed: failed);
  }

  /// Re-derives the status for every non-overridden game based on current playtime
  /// and the user's chosen completion threshold.
  /// Returns the number of games that were auto-completed during this pass.
  Future<int> recalculateAllStatuses(String steamId) async {
    final allGames = await getAllGames(steamId);

    final settings = await (db.select(db.appSettings)
          ..where((s) => s.steamId.equals(steamId)))
        .getSingleOrNull();
    final thresholdStr = settings?.completionThreshold ?? 'essential';
    final threshold = _parseThreshold(thresholdStr);

    final now = DateTime.now();
    int autoCompleted = 0;
    await db.transaction(() async {
      for (final game in allGames) {
        // A completed game the user deliberately re-marked as "playing" keeps
        // its completedAt so it stays in the completed tab. Don't override it.
        if (game.manualOverride &&
            game.status == 'playing' &&
            game.completedAt != null) {
          continue;
        }

        final newStatus = calculateStatus(game, threshold);
        // Skip if status is unchanged, unless completedAt still needs stamping
        // (edge case: games completed before the timestamp column was added).
        final needsStamp = newStatus == GameStatus.completed && game.completedAt == null;
        if (newStatus.name == game.status && !needsStamp) continue;

        if (newStatus == GameStatus.completed && game.status != 'completed') {
          autoCompleted++;
        }

        await (db.update(db.games)..where((g) => g.id.equals(game.id))).write(
          GamesCompanion(
            status: Value(newStatus.name),
            // Stamp completedAt the first time a game is auto-completed so the
            // completed tab can sort it by finish date.
            completedAt: newStatus == GameStatus.completed &&
                    game.completedAt == null
                ? Value(now)
                : const Value.absent(),
          ),
        );
      }
    });
    return autoCompleted;
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
        hltbName: Value(timeToBeat?.hltbName),
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

  // Backlog sorts by remaining time (target − played); completed sorts by absolute hours.
  List<OrderClauseGenerator<$GamesTable>> _orderForBacklog(SortMode mode) =>
      _baseOrder(mode, remaining: true);

  List<OrderClauseGenerator<$GamesTable>> _orderFor(SortMode mode) =>
      _baseOrder(mode);

  /// Single ordering implementation shared by backlog and completed sorts.
  /// [remaining] = true subtracts playtime from the HLTB target (backlog);
  /// [remaining] = false uses absolute target hours (completed).
  List<OrderClauseGenerator<$GamesTable>> _baseOrder(
    SortMode mode, {
    bool remaining = false,
  }) {
    const nullGuard = CustomExpression<double>(
      "COALESCE(essential_hours, extended_hours, completionist_hours)",
    );
    const progressExpr = CustomExpression<double>(
      "CAST(playtime_minutes AS REAL) / 60.0 / "
      "CASE play_style "
      "WHEN 'extended' THEN COALESCE(extended_hours, essential_hours, 9999.0) "
      "WHEN 'completionist' THEN COALESCE(completionist_hours, extended_hours, essential_hours, 9999.0) "
      "ELSE COALESCE(essential_hours, 9999.0) END",
    );
    const remainingExpr = CustomExpression<double>(
      "COALESCE(essential_hours, extended_hours, completionist_hours) - CAST(playtime_minutes AS REAL) / 60.0",
    );

    switch (mode) {
      case SortMode.alphabetical:
        return [(g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc)];
      case SortMode.progress:
        // Denominator uses 9999 so games without HLTB data sink to the bottom.
        return [(g) => OrderingTerm.desc(progressExpr)];
      case SortMode.shortest:
        // Games with no HLTB data go to end; then sort ascending by hours.
        final hoursExpr = remaining ? remainingExpr : nullGuard;
        return [
          (g) => OrderingTerm(expression: nullGuard.isNull(), mode: OrderingMode.asc),
          (g) => OrderingTerm.asc(hoursExpr),
        ];
      case SortMode.longest:
        final hoursExpr = remaining ? remainingExpr : nullGuard;
        return [
          (g) => OrderingTerm(expression: nullGuard.isNull(), mode: OrderingMode.asc),
          (g) => OrderingTerm.desc(hoursExpr),
        ];
      case SortMode.mostPlayed:
        return [(g) => OrderingTerm.desc(g.playtimeMinutes)];
      case SortMode.neglected:
        return [(g) => OrderingTerm.asc(g.addedAt)];
    }
  }

  /// Backlog games sorted by [mode]. Playing games are always pinned to the
  /// top regardless of sort mode. Neglected mode additionally filters to games
  /// with zero playtime. Excludes completed games being re-played.
  /// Shortest/Longest sort by remaining time (target - playtime).
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
          // Playing games float to top ('playing' > 'backlog' alphabetically).
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            ..._orderForBacklog(mode),
          ]))
        .get();
  }

  /// Completed games sorted by [mode], including completed games being re-played.
  /// Re-playing games are always pinned to the top regardless of sort mode.
  Future<List<Game>> completedSorted(SortMode mode, String steamId) {
    return (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals('completed') |
                  (g.status.equals('playing') & g.completedAt.isNotNull())))
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            ..._orderFor(mode),
          ]))
        .get();
  }
}
