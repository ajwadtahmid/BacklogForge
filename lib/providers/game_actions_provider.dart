import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import './database_provider.dart';
import './library_provider.dart';
import './stats_provider.dart';
import './sort_provider.dart';

/// Streams live updates for a single game directly from the DB.
/// The detail screen watches this so it auto-refreshes after any edit
/// without needing explicit invalidation.
final gameDetailProvider = StreamProvider.family<Game?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.games)..where((g) => g.id.equals(id)))
      .watchSingleOrNull();
});

/// Performs mutations on individual games and invalidates all dependent providers.
class GameActions {
  GameActions(this.db, this.ref);
  final AppDatabase db;
  final Ref ref;

  /// Sets the status of [g] to [next], marking it as a manual override so
  /// automatic recalculation won't revert the change on the next sync.
  ///
  /// Pass [preserveCompletedAt] = true when marking a completed game as
  /// "playing" — this keeps the completedAt timestamp so the game remains
  /// visible in the completed tab rather than moving to the backlog.
  Future<void> setStatus(
    Game g,
    GameStatus next, {
    bool preserveCompletedAt = false,
  }) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(
        status: Value(next.name),
        manualOverride: const Value(true),
        completedAt: next == GameStatus.completed
            ? Value(DateTime.now())
            : preserveCompletedAt
                // Stamp completedAt if it was null — old auto-completed games
                // may have null here, which would satisfy the backlog query.
                ? Value(g.completedAt ?? DateTime.now())
                : const Value(null),
      ),
    );
    _invalidateAll();
  }

  /// Updates the play-style preference for [g], which determines which HLTB
  /// estimate drives the progress bar (essential / extended / completionist).
  Future<void> setPlayStyle(Game g, PlayStyle style) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playStyle: Value(style.name)),
    );
    _invalidateAll();
  }

  /// Overrides the recorded playtime for [g] and recalculates completion
  /// status. For Steam games this value will be overwritten on the next sync.
  Future<void> setPlaytime(Game g, double hours) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playtimeMinutes: Value((hours * 60).round())),
    );
    await db.gamesDao.recalculateAllStatuses(g.steamId);
    _invalidateAll();
  }

  /// Overwrites the HLTB time-to-beat estimates and sets manualOverride so the
  /// auto-fetch on sync doesn't clobber the values. Recalculates status after.
  Future<void> setHltbHours(
    Game g, {
    required double? essential,
    required double? extended,
    required double? completionist,
  }) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(
        essentialHours: Value(essential),
        extendedHours: Value(extended),
        completionistHours: Value(completionist),
        manualOverride: const Value(true),
      ),
    );
    await db.gamesDao.recalculateAllStatuses(g.steamId);
    _invalidateAll();
  }

  /// Permanently removes a game from the library. Only callable on manually
  /// added games (negative appId); Steam games are managed by sync.
  Future<void> deleteGame(Game g) async {
    await (db.delete(db.games)..where((tbl) => tbl.id.equals(g.id))).go();
    _invalidateAll();
  }

  void _invalidateAll() {
    ref.invalidate(backlogProvider);
    ref.invalidate(completedProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(backlogSortedProvider);
    ref.invalidate(completedSortedProvider);
  }
}

final gameActionsProvider = Provider((ref) {
  return GameActions(ref.read(databaseProvider), ref);
});
