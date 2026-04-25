import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Aggregated statistics for the current user's game library.
class GameStats {
  const GameStats({
    required this.backlogCount,
    required this.hoursRemaining,
    required this.totalHoursPlayed,
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
  final double hoursRemaining;
  final double totalHoursPlayed;
  final int neverStartedCount;
  final int barelyPlayedCount;
  final int halfwayDoneCount;

  /// Games completed in the last four months.
  final int completedQuarterly;

  final double completionPercent;
  final int playingCount;
  final int hltbCovered;
  final int hltbTotal;

  String get grade {
    if (completionPercent >= 90) return 'A+';
    if (completionPercent >= 80) return 'A';
    if (completionPercent >= 70) return 'A-';
    if (completionPercent >= 60) return 'B+';
    if (completionPercent >= 50) return 'B';
    if (completionPercent >= 40) return 'B-';
    if (completionPercent >= 30) return 'C+';
    if (completionPercent >= 20) return 'C';
    if (completionPercent >= 12) return 'C-';
    if (completionPercent >= 7) return 'D+';
    if (completionPercent >= 3) return 'D';
    return 'D-';
  }
}

final statsProvider = FutureProvider<GameStats>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) {
    return const GameStats(
      backlogCount: 0,
      hoursRemaining: 0,
      totalHoursPlayed: 0,
      neverStartedCount: 0,
      barelyPlayedCount: 0,
      halfwayDoneCount: 0,
      completedQuarterly: 0,
      completionPercent: 0,
      playingCount: 0,
      hltbCovered: 0,
      hltbTotal: 0,
    );
  }

  final s = await ref.watch(databaseProvider).statsDao.computeStats(steamId);
  final total = s.backlog + s.completed;

  return GameStats(
    backlogCount: s.backlog,
    hoursRemaining: s.analysis.hoursRemaining,
    totalHoursPlayed: s.totalHours,
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
