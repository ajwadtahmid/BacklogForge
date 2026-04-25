import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

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

  /// All per-status counts and total playtime in a single SQL pass.
  /// Replaces the four individual count/sum queries.
  Future<({int backlog, int completed, int playing, double totalHours})>
      _aggregateCounts(String steamId) async {
    const backlogExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status IN ('backlog','playing') THEN 1 ELSE 0 END),0)",
    );
    const completedExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END),0)",
    );
    const playingExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN status='playing' THEN 1 ELSE 0 END),0)",
    );
    const minutesExpr = CustomExpression<int>(
      "COALESCE(SUM(playtime_minutes),0)",
    );
    final row = await (selectOnly(games)
          ..addColumns([backlogExpr, completedExpr, playingExpr, minutesExpr])
          ..where(games.steamId.equals(steamId)))
        .getSingle();
    return (
      backlog: row.read(backlogExpr) ?? 0,
      completed: row.read(completedExpr) ?? 0,
      playing: row.read(playingExpr) ?? 0,
      totalHours: (row.read(minutesExpr) ?? 0) / 60.0,
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
      completedQuarterly: quarterly,
      analysis: analysis,
    );
  }

  /// Number of games with status backlog or playing.
  Future<int> backlogCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.status.isIn(['backlog', 'playing']) &
            games.steamId.equals(steamId),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Single-pass analysis of all backlog/playing games. Returns:
  /// - hoursRemaining: per-game remaining hours respecting playStyle
  /// - neverStarted: games with 0 playtime
  /// - barelyPlayed: games with 0 < progress < 10% (requires HLTB data)
  /// - halfwayDone: games with progress ≥ 50% (requires HLTB data)
  /// - hltbCovered/hltbTotal: coverage numerator/denominator
  Future<BacklogAnalysis> backlogStats(String steamId) async {
    final rows = await (select(games)
          ..where(
            (g) =>
                g.status.isIn(['backlog', 'playing']) &
                g.steamId.equals(steamId),
          ))
        .get();

    double hoursRemaining = 0;
    int neverStarted = 0, barelyPlayed = 0, halfwayDone = 0, hltbCovered = 0;

    for (final g in rows) {
      if (g.playtimeMinutes == 0) neverStarted++;

      final target = _targetHours(g);
      if (target == null || target <= 0) continue;

      hltbCovered++;
      final played = g.playtimeMinutes / 60.0;
      final ratio = played / target;

      hoursRemaining += (target - played).clamp(0.0, double.infinity);
      if (g.playtimeMinutes > 0 && ratio < 0.10) barelyPlayed++;
      if (ratio >= 0.50) halfwayDone++;
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

  /// Total hours played across all games for this user.
  Future<double> totalHoursPlayed(String steamId) async {
    final total = games.playtimeMinutes.sum();
    final query = selectOnly(games)
      ..addColumns([total])
      ..where(games.steamId.equals(steamId));
    final row = await query.getSingle();
    return ((row.read(total) ?? 0) / 60.0);
  }

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
        games.status.equals('completed') &
            games.steamId.equals(steamId) &
            games.completedAt.isBiggerOrEqualValue(startOfWindow),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Total number of completed games.
  Future<int> completedCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.status.equals('completed') & games.steamId.equals(steamId),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Number of games currently in the playing state.
  Future<int> playingCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(games.status.equals('playing') & games.steamId.equals(steamId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Resolves target hours respecting the game's stored playStyle.
  double? _targetHours(Game g) {
    final double? preferred = switch (g.playStyle) {
      'extended' => g.extendedHours ?? g.essentialHours,
      'completionist' =>
        g.completionistHours ?? g.extendedHours ?? g.essentialHours,
      _ => g.essentialHours,
    };
    return preferred ?? g.extendedHours ?? g.completionistHours;
  }
}
