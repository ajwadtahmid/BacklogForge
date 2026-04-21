import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Aggregated statistics for the current user's game library.
class GameStats {
  const GameStats({
    required this.backlogCount,
    required this.hoursRemaining,
    required this.completedThisMonth,
    required this.completionPercent,
    required this.playingCount,
    required this.addedThisMonth,
  });

  /// Games with status backlog or playing.
  final int backlogCount;

  /// Sum of extended hours across all backlog games.
  final double hoursRemaining;

  /// Games marked completed since the start of the current calendar month.
  final int completedThisMonth;

  /// Percentage of the total library that is marked completed.
  final double completionPercent;

  /// Games currently in the playing state.
  final int playingCount;

  /// Games added to the library since the start of the current calendar month.
  final int addedThisMonth;

  /// Letter grade derived from [completionPercent].
  String get grade {
    if (completionPercent >= 95) return 'A+';
    if (completionPercent >= 85) return 'A';
    if (completionPercent >= 70) return 'B';
    if (completionPercent >= 30) return 'C';
    return 'D';
  }
}

/// Fetches all stats in parallel and returns a single [GameStats] object.
final statsProvider = FutureProvider<GameStats>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) {
    return const GameStats(
      backlogCount: 0,
      hoursRemaining: 0,
      completedThisMonth: 0,
      completionPercent: 0,
      playingCount: 0,
      addedThisMonth: 0,
    );
  }

  final dao = ref.watch(databaseProvider).statsDao;
  final results = await Future.wait([
    dao.backlogCount(steamId),
    dao.hoursRemaining(steamId),
    dao.completedThisMonth(steamId),
    dao.completedCount(steamId),
    dao.playingCount(steamId),
    dao.addedThisMonth(steamId),
  ]);

  final backlogCount = results[0] as int;
  final completedCount = results[3] as int;
  final total = backlogCount + completedCount;
  final completionPercent = total == 0 ? 0.0 : (completedCount / total) * 100;

  return GameStats(
    backlogCount: backlogCount,
    hoursRemaining: results[1] as double,
    completedThisMonth: results[2] as int,
    completionPercent: completionPercent,
    playingCount: results[4] as int,
    addedThisMonth: results[5] as int,
  );
});
