import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import './database_provider.dart';
import './provider_invalidation.dart';

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
    invalidateAll();
  }

  /// Updates the play-style preference for [g], which determines which HLTB
  /// estimate drives the progress bar (essential / extended / completionist).
  Future<void> setPlayStyle(Game g, PlayStyle style) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playStyle: Value(style.name)),
    );
    invalidateAll();
  }

  /// Overrides the recorded playtime for [g] and recalculates completion
  /// status. For Steam games this value will be overwritten on the next sync.
  Future<void> setPlaytime(Game g, double hours) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playtimeMinutes: Value((hours * 60).round())),
    );
    await db.gamesDao.recalculateAllStatuses(g.steamId);
    invalidateAll();
  }

  /// Overwrites the HLTB time-to-beat estimates and sets manualOverride so the
  /// auto-fetch on sync doesn't clobber the values. Recalculates status after.
  Future<void> setHltbHours(
    Game g, {
    required double? essential,
    required double? extended,
    required double? completionist,
    String? hltbName,
  }) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(
        essentialHours: Value(essential),
        extendedHours: Value(extended),
        completionistHours: Value(completionist),
        hltbName: hltbName != null ? Value(hltbName) : const Value.absent(),
        manualOverride: const Value(true),
      ),
    );
    await db.gamesDao.recalculateAllStatuses(g.steamId);
    invalidateAll();
  }

  /// Permanently removes a game from the library. Only callable on manually
  /// added games (negative appId); Steam games are managed by sync.
  Future<void> deleteGame(Game g) async {
    await (db.delete(db.games)..where((tbl) => tbl.id.equals(g.id))).go();
    invalidateAll();
  }

  /// Marks all [games] as completed with the current timestamp.
  Future<void> bulkMarkCompleted(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      GamesCompanion(
        status: const Value('completed'),
        manualOverride: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
    invalidateAll();
  }

  /// Marks all [games] as playing.
  /// Pass [preserveCompletedAt] = true (completed tab) to keep completedAt so
  /// games remain visible there while replaying.
  Future<void> bulkMarkPlaying(
    List<Game> games, {
    bool preserveCompletedAt = false,
  }) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      GamesCompanion(
        status: const Value('playing'),
        manualOverride: const Value(true),
        completedAt: preserveCompletedAt ? const Value.absent() : const Value(null),
      ),
    );
    invalidateAll();
  }

  /// Marks replaying games (status='playing', completedAt set) back to
  /// completed, keeping their completedAt timestamp intact.
  Future<void> bulkStopReplaying(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      const GamesCompanion(
        status: Value('completed'),
        manualOverride: Value(true),
      ),
    );
    invalidateAll();
  }

  /// Moves all [games] back to the backlog, clearing completedAt.
  Future<void> bulkMoveToBacklog(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      const GamesCompanion(
        status: Value('backlog'),
        manualOverride: Value(true),
        completedAt: Value(null),
      ),
    );
    invalidateAll();
  }

  /// Deletes only manually-added games (appId < 0) from [games].
  /// Returns the number of Steam games that were skipped.
  Future<int> bulkDelete(List<Game> games) async {
    final deletable = games.where((g) => g.appId < 0).toList();
    final skipped = games.length - deletable.length;
    if (deletable.isNotEmpty) {
      final ids = deletable.map((g) => g.id).toList();
      await (db.delete(db.games)..where((g) => g.id.isIn(ids))).go();
      invalidateAll();
    }
    return skipped;
  }

  void invalidateAll() => invalidateLibraryProviders(ref);
}

final gameActionsProvider = Provider((ref) {
  return GameActions(ref.read(databaseProvider), ref);
});
