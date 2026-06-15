import '../constants.dart';
import '../models/time_to_beat.dart';
import 'app_logger.dart';
import 'database/app_database.dart';
import 'database/games_dao.dart';
import 'hltb_service.dart';

/// Orchestrates HLTB batch lookups: filters which games need data, runs
/// concurrent requests in batches, and delegates DB writes to [GamesDao].
///
/// Keeping this logic here (rather than in GamesDao) preserves the DAO as a
/// pure persistence layer and makes the network orchestration independently
/// testable and replaceable.
class HltbSyncService {
  HltbSyncService();

  static const int _kConcurrency = 3;
  final _hltb = HltbService();

  /// Fetches time-to-beat data for any game in [allGames] that does not yet
  /// have it (or whose last attempt is older than [AppConstants.kHltbRetryWindow]).
  ///
  /// Up to [_kConcurrency] requests run concurrently per batch; a
  /// [AppConstants.kHltbRequestGap] pause is inserted between batches to stay
  /// within polite-use limits.
  ///
  /// [onProgress] is called after each game is processed with (current, total).
  /// Returns a record with [fetched] (games that got data) and [failed]
  /// (network/server errors; excludes no-match results).
  Future<({int fetched, int failed})> fetchAllTimeToBeat(
    GamesDao dao,
    List<Game> allGames, {
    void Function(int current, int total)? onProgress,
  }) async {
    final cutoff = DateTime.now().subtract(AppConstants.kHltbRetryWindow);
    final toFetch = allGames
        .where(
          (g) =>
              !g.manualOverride &&
              g.essentialHours == null &&
              g.extendedHours == null &&
              g.completionistHours == null &&
              (g.hltbAttemptedAt == null ||
                  g.hltbAttemptedAt!.isBefore(cutoff)),
        )
        .toList();

    int fetched = 0;
    int failed = 0;
    int processed = 0;

    for (int i = 0; i < toFetch.length; i += _kConcurrency) {
      final batchEnd = (i + _kConcurrency).clamp(0, toFetch.length);

      await Future.wait(toFetch.sublist(i, batchEnd).map((g) async {
        TimeToBeat? data;
        try {
          data = await _hltb.lookup(g.name);
        } catch (e) {
          failed++;
          AppLogger.instance.warning('HLTB lookup failed for "${g.name}"', e);
        }

        if (data != null) fetched++;
        await dao.updateHltbData(g.id, data);
        onProgress?.call(++processed, toFetch.length);
      }));

      if (batchEnd < toFetch.length) {
        await Future.delayed(AppConstants.kHltbRequestGap);
      }
    }

    return (fetched: fetched, failed: failed);
  }
}
