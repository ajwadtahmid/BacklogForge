import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';
import '../../constants.dart';
import '../status_calculator.dart';
import '../../models/time_to_beat.dart';
import '../../models/game_status.dart';

part 'games_dao.g.dart';

/// Sort options available in the backlog and completed tabs.
enum SortMode { alphabetical, progress, shortest, longest, neglected, highestRated }

/// HLTB length bucket filter applied to the backlog list.
enum LengthFilter { any, short, medium, long, noData }

/// Additional filter for rating / notes presence applied to any game list.
enum ExtraFilter { any, rated, withNotes }

@DriftAccessor(tables: [Games])
class GamesDao extends DatabaseAccessor<AppDatabase> with _$GamesDaoMixin {
  GamesDao(super.db);

  /// Finds a game by name for a specific user (used to detect duplicates before manual add).
  Future<Game?> findByName(String name, String steamId) =>
      (select(games)
            ..where((g) => g.name.equals(name) & g.steamId.equals(steamId)))
          .getSingleOrNull();

  /// Returns every game in the library for a user, regardless of status.
  Future<List<Game>> getAllGames(String steamId) =>
      (select(games)..where((g) => g.steamId.equals(steamId))).get();

  /// Reactive stream of all games — used by the unified search.
  Stream<List<Game>> watchAllGames(String steamId) =>
      (select(games)
            ..where((g) => g.steamId.equals(steamId))
            ..orderBy([(g) => OrderingTerm(expression: g.name)]))
          .watch();

  /// Backlog filter: active games (backlog or playing-without-completedAt).
  Expression<bool> _backlogFilter($GamesTable g, String steamId) =>
      g.steamId.equals(steamId) &
      (g.status.equals(GameStatus.backlog.name) |
          (g.status.equals(GameStatus.playing.name) & g.completedAt.isNull()));

  /// Completed filter: finished games plus re-playing games (playing with completedAt).
  Expression<bool> _completedFilter($GamesTable g, String steamId) =>
      g.steamId.equals(steamId) &
      (g.status.equals(GameStatus.completed.name) |
          (g.status.equals(GameStatus.playing.name) & g.completedAt.isNotNull()));

  /// Backlog tab: actively-playing games (without a completedAt) pinned to top,
  /// then unstarted backlog alphabetically. Excludes completed games being re-played.
  Future<List<Game>> getBacklog(String steamId) {
    return (select(games)
          ..where((g) => _backlogFilter(g, steamId))
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            (g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Persists HLTB lookup result for one game.
  /// Pass [data] = null to stamp [hltbAttemptedAt] without writing hours
  /// (records a failed/no-match attempt so the retry window applies).
  Future<void> updateHltbData(int gameId, TimeToBeat? data) async {
    final now = DateTime.now();
    if (data != null) {
      await (db.update(db.games)..where((t) => t.id.equals(gameId))).write(
        GamesCompanion(
          essentialHours: Value(data.essentialHours),
          extendedHours: Value(data.extendedHours),
          completionistHours: Value(data.completionistHours),
          hltbName: Value(data.hltbName),
          hltbAttemptedAt: Value(now),
        ),
      );
    } else {
      await (db.update(db.games)..where((t) => t.id.equals(gameId))).write(
        GamesCompanion(hltbAttemptedAt: Value(now)),
      );
    }
  }

  /// Re-derives the status for every non-overridden game based on current playtime
  /// and the user's chosen completion threshold.
  ///
  /// Computes all needed transitions in memory, then issues at most four bulk
  /// UPDATE statements (one per target status × stamp-needed). This replaces the
  /// previous per-row UPDATE loop and runs in O(1) round-trips regardless of
  /// library size.
  ///
  /// Returns the number of games that were auto-completed during this pass.
  Future<int> recalculateAllStatuses(String steamId) async {
    final allGames = await getAllGames(steamId);

    final settings = await (db.select(db.appSettings)
          ..where((s) => s.steamId.equals(steamId)))
        .getSingleOrNull();
    final threshold = _parseThreshold(settings?.completionThreshold ?? 'essential');

    final now = DateTime.now();
    int autoCompleted = 0;

    final toBacklog = <int>[];
    final toPlaying = <int>[];
    final toCompletedAlreadyStamped = <int>[];
    final toCompletedNeedsStamp = <int>[];

    for (final game in allGames) {
      // A completed game deliberately re-marked as "playing" keeps its
      // completedAt so it stays in the completed tab. Don't override it.
      if (game.manualOverride &&
          game.status == GameStatus.playing.name &&
          game.completedAt != null) {
        continue;
      }

      final newStatus = calculateStatus(game, threshold);
      final needsStamp = newStatus == GameStatus.completed && game.completedAt == null;
      if (newStatus.name == game.status && !needsStamp) continue;

      if (newStatus == GameStatus.completed &&
          game.status != GameStatus.completed.name) {
        autoCompleted++;
      }

      switch (newStatus) {
        case GameStatus.completed:
          if (needsStamp) {
            toCompletedNeedsStamp.add(game.id);
          } else {
            toCompletedAlreadyStamped.add(game.id);
          }
        case GameStatus.playing:
          toPlaying.add(game.id);
        case GameStatus.backlog:
          toBacklog.add(game.id);
      }
    }

    if (toBacklog.isEmpty &&
        toPlaying.isEmpty &&
        toCompletedAlreadyStamped.isEmpty &&
        toCompletedNeedsStamp.isEmpty) {
      return autoCompleted;
    }

    // Drift coalesces watch notifications per transaction, so all list/stat
    // streams will fire exactly once after all updates below.
    await db.transaction(() async {
      if (toBacklog.isNotEmpty) {
        await (db.update(db.games)..where((g) => g.id.isIn(toBacklog)))
            .write(GamesCompanion(status: Value(GameStatus.backlog.name)));
      }
      if (toPlaying.isNotEmpty) {
        await (db.update(db.games)..where((g) => g.id.isIn(toPlaying)))
            .write(GamesCompanion(status: Value(GameStatus.playing.name)));
      }
      if (toCompletedAlreadyStamped.isNotEmpty) {
        await (db.update(db.games)
              ..where((g) => g.id.isIn(toCompletedAlreadyStamped)))
            .write(GamesCompanion(
              status: Value(GameStatus.completed.name),
            ));
      }
      if (toCompletedNeedsStamp.isNotEmpty) {
        await (db.update(db.games)
              ..where((g) => g.id.isIn(toCompletedNeedsStamp)))
            .write(GamesCompanion(
              status: Value(GameStatus.completed.name),
              completedAt: Value(now),
            ));
      }
    });

    return autoCompleted;
  }

  /// Recalculates completion status for a single [game] — use after per-game
  /// edits (playtime, HLTB hours) instead of the full-library [recalculateAllStatuses].
  /// Re-reads the row first so it sees the already-committed updated values.
  Future<void> recalculateStatus(Game game) async {
    final current = await (db.select(db.games)
          ..where((g) => g.id.equals(game.id)))
        .getSingleOrNull();
    if (current == null) return;

    // A completed game being replayed keeps its status; skip it.
    if (current.manualOverride &&
        current.status == GameStatus.playing.name &&
        current.completedAt != null) {
      return;
    }

    final settings = await (db.select(db.appSettings)
          ..where((s) => s.steamId.equals(current.steamId)))
        .getSingleOrNull();
    final threshold =
        _parseThreshold(settings?.completionThreshold ?? 'essential');

    final newStatus = calculateStatus(current, threshold);
    final needsStamp =
        newStatus == GameStatus.completed && current.completedAt == null;

    if (newStatus.name == current.status && !needsStamp) return;

    await (db.update(db.games)..where((g) => g.id.equals(current.id))).write(
      GamesCompanion(
        status: Value(newStatus.name),
        completedAt: needsStamp ? Value(DateTime.now()) : const Value.absent(),
      ),
    );
  }

  /// Returns the next available negative appId for a manually-added game.
  /// Uses min(existing negative appId) - 1 so it can never collide, regardless
  /// of how quickly successive games are added.
  Future<int> _nextManualAppId(String steamId) async {
    final minExpr = games.appId.min();
    final row = await (selectOnly(games)
          ..addColumns([minExpr])
          ..where(games.steamId.equals(steamId)))
        .getSingle();
    final currentMin = row.read(minExpr) ?? 0;
    return (currentMin < 0 ? currentMin : 0) - 1;
  }

  /// Inserts a manually-searched game with a negative appId (to distinguish it
  /// from Steam games) and optional HLTB time-to-beat data.
  Future<int> addManualGame(
      String gameName, TimeToBeat? timeToBeat, String steamId,
      {String? artworkUrl, GameStatus status = GameStatus.backlog}) async {
    final negativeId = await _nextManualAppId(steamId);
    return into(games).insert(
      GamesCompanion.insert(
        steamId: steamId,
        appId: negativeId,
        name: gameName,
        status: Value(status.name),
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

  /// Upserts a list of games from a JSON import, replacing any existing row
  /// with the same (steamId, appId) pair so a backup restore is idempotent.
  ///
  /// Note: `insertOrReplace` deletes and re-inserts matching rows, so the
  /// autoincrement `id` column will be reassigned. This is safe today because
  /// no cross-table foreign keys reference `id`, but a future feature that
  /// stores stable game references should use a stable key (e.g. `appId`)
  /// rather than the row `id`.
  Future<int> importGames(
      String steamId, List<GamesCompanion> companions) async {
    int count = 0;
    await db.transaction(() async {
      for (final c in companions) {
        await into(games).insert(
          c.copyWith(steamId: Value(steamId)),
          mode: InsertMode.insertOrReplace,
        );
        count++;
      }
    });
    return count;
  }

  CompletionThreshold _parseThreshold(String value) =>
      CompletionThreshold.values.asNameMap()[value] ?? CompletionThreshold.essential;

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
    const s = AppConstants.kSortNoDataSentinel;
    const progressExpr = CustomExpression<double>(
      "CAST(playtime_minutes AS REAL) / 60.0 / "
      "CASE play_style "
      "WHEN 'extended' THEN COALESCE(extended_hours, essential_hours, $s) "
      "WHEN 'completionist' THEN COALESCE(completionist_hours, extended_hours, essential_hours, $s) "
      "ELSE COALESCE(essential_hours, $s) END",
    );
    const remainingExpr = CustomExpression<double>(
      "COALESCE(essential_hours, extended_hours, completionist_hours) - CAST(playtime_minutes AS REAL) / 60.0",
    );

    switch (mode) {
      case SortMode.alphabetical:
        return [(g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc)];
      case SortMode.progress:
        return [(g) => OrderingTerm.desc(progressExpr)];
      case SortMode.shortest:
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
      case SortMode.neglected:
        return [(g) => OrderingTerm.asc(g.addedAt)];
      case SortMode.highestRated:
        return [
          (g) => OrderingTerm(expression: g.rating.isNull(), mode: OrderingMode.asc),
          (g) => OrderingTerm.desc(g.rating),
        ];
    }
  }

  /// Translates a [LengthFilter] into a SQL WHERE clause fragment using raw
  /// expressions so it works without needing nullable-typed column helpers.
  Expression<bool> _lengthFilter($GamesTable g, LengthFilter filter) {
    switch (filter) {
      case LengthFilter.any:
        return const CustomExpression<bool>('1');
      case LengthFilter.short:
        return CustomExpression<bool>(
          "COALESCE(essential_hours, extended_hours, completionist_hours) IS NOT NULL"
          " AND COALESCE(essential_hours, extended_hours, completionist_hours) < ${AppConstants.kShortGameHours}",
        );
      case LengthFilter.medium:
        return CustomExpression<bool>(
          "COALESCE(essential_hours, extended_hours, completionist_hours) >= ${AppConstants.kShortGameHours}"
          " AND COALESCE(essential_hours, extended_hours, completionist_hours) < ${AppConstants.kMediumGameHours}",
        );
      case LengthFilter.long:
        return CustomExpression<bool>(
          "COALESCE(essential_hours, extended_hours, completionist_hours) >= ${AppConstants.kMediumGameHours}",
        );
      case LengthFilter.noData:
        return const CustomExpression<bool>(
          "essential_hours IS NULL AND extended_hours IS NULL AND completionist_hours IS NULL",
        );
    }
  }

  Expression<bool> _extraFilter($GamesTable g, ExtraFilter filter) {
    switch (filter) {
      case ExtraFilter.any:
        return const CustomExpression<bool>('1');
      case ExtraFilter.rated:
        return g.rating.isNotNull();
      case ExtraFilter.withNotes:
        return g.notes.isNotNull() & g.notes.isNotValue('');
    }
  }

  /// Reactive backlog stream — re-emits whenever the games table
  /// changes. The [StreamProvider] resubscribes automatically when [mode] or
  /// [filter] changes, so the list is always consistent with current prefs.
  Stream<List<Game>> watchBacklogSorted(
    SortMode mode,
    String steamId, {
    LengthFilter filter = LengthFilter.any,
    ExtraFilter extraFilter = ExtraFilter.any,
  }) {
    return (select(games)
          ..where((g) {
            final isBacklog = _backlogFilter(g, steamId);
            final base = mode == SortMode.neglected
                ? isBacklog & g.playtimeMinutes.equals(0)
                : isBacklog;
            return base & _lengthFilter(g, filter) & _extraFilter(g, extraFilter);
          })
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            ..._orderForBacklog(mode),
          ]))
        .watch();
  }

  /// Reactive version of the completed sort.
  Stream<List<Game>> watchCompletedSorted(
    SortMode mode,
    String steamId, {
    ExtraFilter extraFilter = ExtraFilter.any,
  }) {
    return (select(games)
          ..where((g) => _completedFilter(g, steamId) & _extraFilter(g, extraFilter))
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            ..._orderFor(mode),
          ]))
        .watch();
  }
}
