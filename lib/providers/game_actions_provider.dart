import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import './database_provider.dart';

/// Streams live updates for a single game directly from the DB.
/// The detail screen watches this so it auto-refreshes after any edit
/// without needing explicit invalidation.
final gameDetailProvider = StreamProvider.family<Game?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.games)..where((g) => g.id.equals(id)))
      .watchSingleOrNull();
});

/// Performs mutations on individual games. List and stat providers update
/// automatically via Drift's reactive watch streams — no manual invalidation.
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
                ? Value(g.completedAt ?? DateTime.now())
                : const Value(null),
      ),
    );
  }

  /// Updates the play-style preference for [g], which determines which HLTB
  /// estimate drives the progress bar (essential / extended / completionist).
  Future<void> setPlayStyle(Game g, PlayStyle style) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playStyle: Value(style.name)),
    );
  }

  /// Overrides the recorded playtime for [g] and recalculates completion
  /// status. For Steam games this value will be overwritten on the next sync.
  Future<void> setPlaytime(Game g, double hours) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(playtimeMinutes: Value((hours * 60).round())),
    );
    await db.gamesDao.recalculateStatus(g);
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
    await db.gamesDao.recalculateStatus(g);
  }

  /// Saves a personal note for [g]. Pass null to clear.
  Future<void> setNotes(Game g, String? notes) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(notes: Value(notes?.isEmpty == true ? null : notes)),
    );
  }

  /// Sets the personal rating (1–10) for [g]. Pass null to clear.
  Future<void> setRating(Game g, int? rating) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(rating: Value(rating)),
    );
  }

  /// Permanently removes a game from the library. Only callable on manually
  /// added games (negative appId); Steam games are managed by sync.
  Future<void> deleteGame(Game g) async {
    await (db.delete(db.games)..where((tbl) => tbl.id.equals(g.id))).go();
  }

  /// Marks all [games] as completed with the current timestamp.
  Future<void> bulkMarkCompleted(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      GamesCompanion(
        status: Value(GameStatus.completed.name),
        manualOverride: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
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
        status: Value(GameStatus.playing.name),
        manualOverride: const Value(true),
        completedAt: preserveCompletedAt ? const Value.absent() : const Value(null),
      ),
    );
  }

  /// Marks replaying games (status='playing', completedAt set) back to
  /// completed, keeping their completedAt timestamp intact.
  Future<void> bulkStopReplaying(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      GamesCompanion(
        status: Value(GameStatus.completed.name),
        manualOverride: const Value(true),
      ),
    );
  }

  /// Moves all [games] back to the backlog, clearing completedAt.
  Future<void> bulkMoveToBacklog(List<Game> games) async {
    if (games.isEmpty) return;
    final ids = games.map((g) => g.id).toList();
    await (db.update(db.games)..where((g) => g.id.isIn(ids))).write(
      GamesCompanion(
        status: Value(GameStatus.backlog.name),
        manualOverride: const Value(true),
        completedAt: const Value(null),
      ),
    );
  }

  /// Deletes only manually-added games (appId < 0) from [games].
  /// Returns the number of Steam games that were skipped.
  Future<int> bulkDelete(List<Game> games) async {
    final deletable = games.where((g) => g.appId < 0).toList();
    final skipped = games.length - deletable.length;
    if (deletable.isNotEmpty) {
      final ids = deletable.map((g) => g.id).toList();
      await (db.delete(db.games)..where((g) => g.id.isIn(ids))).go();
    }
    return skipped;
  }
}

final gameActionsProvider = Provider((ref) {
  return GameActions(ref.read(databaseProvider), ref);
});
