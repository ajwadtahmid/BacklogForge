import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';
import '../igdb_service.dart';
import '../status_calculator.dart';

part 'games_dao.g.dart';

/// Data access object for game-related database operations.
/// Handles querying games, fetching completion time data from IGDB, and recalculating game statuses.
@DriftAccessor(tables: [Games])
class GamesDao extends DatabaseAccessor<AppDatabase> with _$GamesDaoMixin {
  GamesDao(super.db);

  final _igdb = IgdbService();

  // Insert or replace by appId. Used by Steam sync and manual game add.
  Future<int> upsert(GamesCompanion g) => into(games).insertOnConflictUpdate(g);

  Future<Game?> findByAppId(int appId) =>
      (select(games)..where((g) => g.appId.equals(appId))).getSingleOrNull();

  Future<List<Game>> getAllGames() => select(games).get();

  // Backlog tab: playing + backlog rows, playing pinned to the top,
  // then case-insensitive alphabetical by name.
  Future<List<Game>> getBacklog() {
    return (select(games)
          ..where((g) => g.status.isIn(['backlog', 'playing']))
          ..orderBy([
            (g) => OrderingTerm.desc(g.status),
            (g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  // Completed tab: most recently finished first.
  Future<List<Game>> getCompleted() {
    return (select(games)
          ..where((g) => g.status.equals('completed'))
          ..orderBy([(g) => OrderingTerm.desc(g.completedAt)]))
        .get();
  }

  // Auto-updating stream — UI rebuilds when any row changes.
  Stream<List<Game>> watchBacklog() {
    return (select(
      games,
    )..where((g) => g.status.isIn(['backlog', 'playing']))).watch();
  }

  /// Returns the number of games that received new time-to-beat data.
  Future<int> fetchAllTimeToBeat(List<Game> games) async {
    int fetched = 0;
    for (final g in games) {
      // Skip if already have time-to-beat data, or if user has manually set the status.
      if (g.manualOverride ||
          g.rushedHours != null ||
          g.casuallyHours != null ||
          g.completionistHours != null) {
        continue;
      }
      try {
        final data = await _igdb.lookup(g.name);
        if (data != null) {
          fetched++;
          await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id)))
              .write(
            GamesCompanion(
              rushedHours: Value(data.rushedHours),
              casuallyHours: Value(data.casuallyHours),
              completionistHours: Value(data.completionistHours),
            ),
          );
        }
      } catch (e) {
        // Silently skip games that fail IGDB lookup; they'll retry on next sync.
      }
      // IGDB allows 4 req/s; each game needs 2 requests (search + time_to_beat).
      // Rate limit enforced via 550ms delay between lookups.
      await Future.delayed(const Duration(milliseconds: 550));
    }
    return fetched;
  }

  /// Recalculates status for all games based on time-to-beat and playtime, respecting manual overrides.
  Future<void> recalculateAllStatuses() async {
    final games = await select(db.games).get();

    // Get user's completion threshold preference, migrating legacy values.
    final settings = await (db.select(db.appSettings)..where((s) => s.id.equals(1))).getSingleOrNull();
    final thresholdStr = settings?.completionThreshold ?? 'casually';
    final threshold = _parseThreshold(thresholdStr);

    // Calculate and update status for each game in a single transaction for consistency.
    await db.transaction(() async {
      for (final game in games) {
        // Skip games with manual status overrides; their status is user-controlled.
        if (game.manualOverride) continue;

        final newStatus = calculateStatus(game, threshold);

        await (db.update(db.games)..where((g) => g.id.equals(game.id))).write(
          GamesCompanion(status: Value(newStatus.name)),
        );
      }
    });
  }

  /// Maps legacy DB values (e.g. 'main') to the current enum, defaulting to casually.
  CompletionThreshold _parseThreshold(String value) {
    const legacy = {
      'main': CompletionThreshold.casually,
      'mainPlusExtras': CompletionThreshold.casually,
    };
    return legacy[value] ??
        CompletionThreshold.values.asNameMap()[value] ??
        CompletionThreshold.casually;
  }
}
