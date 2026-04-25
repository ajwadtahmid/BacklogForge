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

  final dao = ref.watch(databaseProvider).statsDao;
  final results = await Future.wait([
    dao.backlogCount(steamId),              // 0
    dao.completedLastFourMonths(steamId),   // 1
    dao.completedCount(steamId),            // 2
    dao.playingCount(steamId),              // 3
    dao.totalHoursPlayed(steamId),          // 4
    dao.backlogStats(steamId),              // 5
  ]);

  final backlogCount = results[0] as int;
  final completedCount = results[2] as int;
  final total = backlogCount + completedCount;
  final completionPercent = total == 0 ? 0.0 : (completedCount / total) * 100;
  final analysis = results[5] as ({
    double hoursRemaining,
    int neverStarted,
    int barelyPlayed,
    int halfwayDone,
    int hltbCovered,
    int hltbTotal,
  });

  return GameStats(
    backlogCount: backlogCount,
    hoursRemaining: analysis.hoursRemaining,
    totalHoursPlayed: results[4] as double,
    neverStartedCount: analysis.neverStarted,
    barelyPlayedCount: analysis.barelyPlayed,
    halfwayDoneCount: analysis.halfwayDone,
    completedQuarterly: results[1] as int,
    completionPercent: completionPercent,
    playingCount: results[3] as int,
    hltbCovered: analysis.hltbCovered,
    hltbTotal: analysis.hltbTotal,
  );
});
