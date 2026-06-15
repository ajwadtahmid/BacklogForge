import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Aggregated statistics for the current user's game library.
class GameStats {
  const GameStats({
    required this.backlogCount,
    required this.completedCount,
    required this.hoursRemaining,
    required this.totalHoursPlayed,
    required this.avgCompletionHours,
    required this.neverStartedCount,
    required this.barelyPlayedCount,
    required this.halfwayDoneCount,
    required this.completedQuarterly,
    required this.completionPercent,
    required this.playingCount,
    required this.hltbCovered,
    required this.hltbTotal,
  });

  final int backlogCount;
  final int completedCount;
  final double hoursRemaining;
  final double totalHoursPlayed;

  /// Average playtime (hours) for completed games. Null if no games completed.
  final double? avgCompletionHours;

  final int neverStartedCount;
  final int barelyPlayedCount;
  final int halfwayDoneCount;

  /// Games completed in the last four months.
  final int completedQuarterly;

  final double completionPercent;
  final int playingCount;
  final int hltbCovered;
  final int hltbTotal;

  static const empty = GameStats(
    backlogCount: 0,
    completedCount: 0,
    hoursRemaining: 0,
    totalHoursPlayed: 0,
    avgCompletionHours: null,
    neverStartedCount: 0,
    barelyPlayedCount: 0,
    halfwayDoneCount: 0,
    completedQuarterly: 0,
    completionPercent: 0,
    playingCount: 0,
    hltbCovered: 0,
    hltbTotal: 0,
  );

  static const _gradeBands = [
    (90.0, 'A+'), (80.0, 'A'),  (70.0, 'A-'),
    (60.0, 'B+'), (50.0, 'B'),  (40.0, 'B-'),
    (30.0, 'C+'), (20.0, 'C'),  (12.0, 'C-'),
    (7.0,  'D+'), (3.0,  'D'),
  ];

  String get grade {
    for (final (threshold, label) in _gradeBands) {
      if (completionPercent >= threshold) return label;
    }
    return 'D-';
  }
}

/// Reactive per-month completion counts for the velocity chart.
final completionVelocityProvider =
    StreamProvider<List<({int year, int month, int count})>>((ref) {
  final steamId = ref.watch(authProvider).asData?.value.steamId;
  if (steamId == null) return Stream.value([]);
  return ref.watch(databaseProvider).statsDao.watchCompletedByMonth(steamId);
});

/// Reactive stats provider backed by a Drift watch stream. Re-emits whenever
/// any game row changes for the current user; no manual invalidation required.
final statsProvider = StreamProvider<GameStats>((ref) {
  final steamId = ref.watch(authProvider).asData?.value.steamId;
  if (steamId == null) return Stream.value(GameStats.empty);

  return ref.watch(databaseProvider).statsDao.watchComputedStats(steamId).map((s) {
    final total = s.backlog + s.completed;
    return GameStats(
      backlogCount: s.backlog,
      completedCount: s.completed,
      hoursRemaining: s.analysis.hoursRemaining,
      totalHoursPlayed: s.totalHours,
      avgCompletionHours: s.avgCompletionHours,
      neverStartedCount: s.analysis.neverStarted,
      barelyPlayedCount: s.analysis.barelyPlayed,
      halfwayDoneCount: s.analysis.halfwayDone,
      completedQuarterly: s.completedQuarterly,
      completionPercent: total == 0 ? 0.0 : (s.completed / total) * 100,
      playingCount: s.playing,
      hltbCovered: s.analysis.hltbCovered,
      hltbTotal: s.analysis.hltbTotal,
    );
  });
});
