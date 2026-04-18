import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import './database_provider.dart';
import './library_provider.dart';

class GameActions {
  GameActions(this.db, this.ref);
  final AppDatabase db;
  final Ref ref;

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
    ref.invalidate(backlogProvider);
    ref.invalidate(completedProvider);
  }
}

final gameActionsProvider = Provider((ref) {
  return GameActions(ref.read(databaseProvider), ref);
});
