import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game_status.dart';
import './database_provider.dart';
import './library_provider.dart';
import './stats_provider.dart';
import './sort_provider.dart';

/// Performs mutations on individual games and invalidates all dependent providers.
class GameActions {
  GameActions(this.db, this.ref);
  final AppDatabase db;
  final Ref ref;

  /// Sets the status of [g] to [next], marking it as a manual override so
  /// automatic recalculation won't revert the change on the next sync.
  Future<void> setStatus(Game g, GameStatus next) async {
    await (db.update(db.games)..where((tbl) => tbl.id.equals(g.id))).write(
      GamesCompanion(
        status: Value(next.name),
        manualOverride: const Value(true),
        completedAt: next == GameStatus.completed
            ? Value(DateTime.now())
            : const Value(null),
      ),
    );
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
