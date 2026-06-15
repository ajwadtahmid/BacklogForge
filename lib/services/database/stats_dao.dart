import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'app_database.dart';
import 'tables.dart';
import '../../constants.dart';
import '../../models/game.dart';
import '../../models/game_status.dart';

part 'stats_dao.g.dart';

/// Aggregated results derived from a single pass over all backlog/playing rows.
typedef BacklogAnalysis = ({
  double hoursRemaining,
  int neverStarted,
  int barelyPlayed,
  int halfwayDone,
  int hltbCovered,
  int hltbTotal,
});

@DriftAccessor(tables: [Games])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.db);

  /// All per-status counts, total playtime, and average completion time in a
  /// single SQL pass.
  ///
  /// A game re-marked as "playing" after completion (status='playing',
  /// completed_at NOT NULL) counts as completed, matching the completed-tab
  /// filter — so the completion grade doesn't drop when a user replays a game.
  Future<({int backlog, int completed, int playing, double totalHours, double? avgCompletionHours})>
      _aggregateCounts(String steamId) async {
    const backlogExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status IN ('backlog','playing') AND completed_at IS NULL THEN 1 ELSE 0 END),0)",
    );
    const completedExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status='completed' OR (status='playing' AND completed_at IS NOT NULL) THEN 1 ELSE 0 END),0)",
    );
    const playingExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status='playing' THEN 1 ELSE 0 END),0)",
    );
    const minutesExpr = CustomExpression<int>(
      "COALESCE(SUM(playtime_minutes),0)",
    );
    // AVG ignores NULLs — CASE returns NULL for non-completed rows so this
    // computes the mean only over completed games. Returns NULL if none exist.
    const avgCompletionExpr = CustomExpression<double>(
      "AVG(CASE WHEN status='completed' OR (status='playing' AND completed_at IS NOT NULL)"
      " THEN CAST(playtime_minutes AS REAL) / 60.0 ELSE NULL END)",
    );
    final row = await (selectOnly(games)
          ..addColumns([backlogExpr, completedExpr, playingExpr, minutesExpr, avgCompletionExpr])
          ..where(games.steamId.equals(steamId)))
        .getSingle();
    return (
      backlog: row.read(backlogExpr) ?? 0,
      completed: row.read(completedExpr) ?? 0,
      playing: row.read(playingExpr) ?? 0,
      totalHours: (row.read(minutesExpr) ?? 0) / 60.0,
      avgCompletionHours: row.read(avgCompletionExpr),
    );
  }

  /// Computes all library statistics in 3 parallel queries instead of 6.
  /// Returns a record consumed directly by [statsProvider].
  Future<
      ({
        int backlog,
        int completed,
        int playing,
        double totalHours,
        double? avgCompletionHours,
        int completedQuarterly,
        BacklogAnalysis analysis,
      })> computeStats(String steamId) async {
    // Fire all three in parallel; each awaits independently.
    final countsFuture = _aggregateCounts(steamId);
    final quarterlyFuture = completedLastFourMonths(steamId);
    final analysisFuture = backlogStats(steamId);
    final counts = await countsFuture;
    final quarterly = await quarterlyFuture;
    final analysis = await analysisFuture;
    return (
      backlog: counts.backlog,
      completed: counts.completed,
      playing: counts.playing,
      totalHours: counts.totalHours,
      avgCompletionHours: counts.avgCompletionHours,
      completedQuarterly: quarterly,
      analysis: analysis,
    );
  }

  /// Single-pass analysis of all backlog/playing games. Returns:
  /// - hoursRemaining: per-game remaining hours respecting playStyle
  /// - neverStarted: games with 0 playtime
  /// - barelyPlayed: games with 0 < progress < 10% (requires HLTB data)
  /// - halfwayDone: games with progress ≥ 50% (requires HLTB data)
  /// - hltbCovered/hltbTotal: coverage numerator/denominator
  Future<BacklogAnalysis> backlogStats(String steamId) async {
    // Mirror the backlog filter: exclude completed-but-replaying games so the
    // hours-remaining and progress buckets reflect only genuinely unfinished work.
    final rows = await (select(games)
          ..where(
            (g) =>
                (g.status.equals(GameStatus.backlog.name) |
                    (g.status.equals(GameStatus.playing.name) &
                        g.completedAt.isNull())) &
                g.steamId.equals(steamId),
          ))
        .get();

    double hoursRemaining = 0;
    int neverStarted = 0, barelyPlayed = 0, halfwayDone = 0, hltbCovered = 0;

    for (final g in rows) {
      if (g.playtimeMinutes == 0) neverStarted++;

      final target = g.displayTargetHours;
      if (target == null || target <= 0) continue;

      hltbCovered++;
      final played = g.playtimeMinutes / 60.0;
      final ratio = played / target;

      hoursRemaining += (target - played).clamp(0.0, double.infinity);
      if (g.playtimeMinutes > 0 && ratio < AppConstants.kBarelyPlayedRatio) {
        barelyPlayed++;
      }
      if (ratio >= AppConstants.kHalfwayRatio) halfwayDone++;
    }

    return (
      hoursRemaining: hoursRemaining,
      neverStarted: neverStarted,
      barelyPlayed: barelyPlayed,
      halfwayDone: halfwayDone,
      hltbCovered: hltbCovered,
      hltbTotal: rows.length,
    );
  }

  /// Reactive stream of computed stats. Re-emits whenever any game row for
  /// [steamId] changes; the [StreamProvider] consumer maps the raw record to
  /// [GameStats]. Debounced so rapid bulk mutations (import, sync) collapse
  /// into a single recompute.
  Stream<({int backlog, int completed, int playing, double totalHours, double? avgCompletionHours, int completedQuarterly, BacklogAnalysis analysis})>
      watchComputedStats(String steamId) {
    return (select(games)..where((g) => g.steamId.equals(steamId)))
        .watch()
        .debounceTime(const Duration(milliseconds: 300))
        .asyncMap((_) => computeStats(steamId));
  }

  /// Per-month completion counts, sorted oldest-first.
  /// Fetches all completed games for the user and aggregates in Dart to avoid
  /// relying on SQLite date-format details (Drift stores DateTime as INTEGER seconds).
  Future<List<({int year, int month, int count})>> completedByMonth(
      String steamId) async {
    // Mirror the completedExpr logic: include replaying games (status='playing'
    // with completedAt set) so the chart stays consistent with all other stats.
    final rows = await (select(games)
          ..where((g) =>
              g.steamId.equals(steamId) &
              (g.status.equals(GameStatus.completed.name) |
               (g.status.equals(GameStatus.playing.name) & g.completedAt.isNotNull())) &
              g.completedAt.isNotNull()))
        .get();

    final buckets = <(int, int), int>{};
    for (final g in rows) {
      final dt = g.completedAt!;
      final key = (dt.year, dt.month);
      buckets[key] = (buckets[key] ?? 0) + 1;
    }

    return (buckets.entries
          .map((e) => (year: e.key.$1, month: e.key.$2, count: e.value))
          .toList())
      ..sort((a, b) =>
          a.year != b.year ? a.year.compareTo(b.year) : a.month.compareTo(b.month));
  }

  /// Reactive version — re-emits whenever any game changes, debounced.
  Stream<List<({int year, int month, int count})>> watchCompletedByMonth(
          String steamId) =>
      (select(games)..where((g) => g.steamId.equals(steamId)))
          .watch()
          .debounceTime(const Duration(milliseconds: 300))
          .asyncMap((_) => completedByMonth(steamId));

  /// Number of games completed in the last four months (current month + prior 3).
  Future<int> completedLastFourMonths(String steamId) async {
    final now = DateTime.now();
    // Dart's DateTime constructor normalises out-of-range months, so month-3
    // is safe even in Jan–Mar (e.g. March 2026 → December 2025). The window
    // intentionally starts on the 1st of that month, not the same day.
    final startOfWindow = DateTime(now.year, now.month - 3);
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        (games.status.equals(GameStatus.completed.name) |
            (games.status.equals(GameStatus.playing.name) & games.completedAt.isNotNull())) &
            games.steamId.equals(steamId) &
            games.completedAt.isBiggerOrEqualValue(startOfWindow),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

}
