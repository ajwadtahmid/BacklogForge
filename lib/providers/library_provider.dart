import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import '../services/steam_service.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Fetches backlog and playing games from the database.
final backlogProvider = FutureProvider<List<Game>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.gamesDao.getBacklog();
});

/// Fetches completed games from the database.
final completedProvider = FutureProvider<List<Game>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.gamesDao.getCompleted();
});

/// Tracks sync state: idle, syncing, or error.
enum SyncStatus { idle, syncing, error }

/// Represents the current state of a Steam library sync operation.
class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  const SyncState({this.status = SyncStatus.idle, this.errorMessage});
}

final syncStateProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Manages syncing the user's Steam game library with the local database.
/// Fetches owned games and time-to-beat data, updating the database only when changes are detected.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;
    state = const SyncState(status: SyncStatus.syncing);

    try {
      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId;
      if (steamId == null) throw Exception('Not signed in');

      final db = ref.read(databaseProvider);
      final steamService = SteamService();
      bool hasChanges = false;

      // Snapshot current state for change detection
      final existing = await db.gamesDao.getAllGames();
      final oldPlaytime = {
        for (final g in existing) g.appId: g.playtimeMinutes,
      };

      // Fetch games from Steam API and batch upsert.
      // On conflict (existing appId), only update name and playtime —
      // preserves status, manualOverride, and time-to-beat data.
      final steamGames = await steamService.getOwnedGames(steamId);
      final now = DateTime.now();
      await db.transaction(() async {
        for (final game in steamGames) {
          await db.into(db.games).insert(
            GamesCompanion.insert(
              appId: game.appId,
              name: game.name,
              playtimeMinutes: Value(game.playtimeMinutes),
              addedAt: now,
            ),
            onConflict: DoUpdate(
              (old) => GamesCompanion(
                name: Value(game.name),
                playtimeMinutes: Value(game.playtimeMinutes),
              ),
              target: [db.games.appId],
            ),
          );
        }
      });

      // Detect changes: new games or updated playtime
      for (final game in steamGames) {
        final old = oldPlaytime[game.appId];
        if (old == null || old != game.playtimeMinutes) {
          hasChanges = true;
          break;
        }
      }

      // Fetch time-to-beat data from IGDB (only for uncached games)
      final allGames = await db.gamesDao.getAllGames();
      final newTimeToBeat = await db.gamesDao.fetchAllTimeToBeat(allGames);
      if (newTimeToBeat > 0) hasChanges = true;

      // Recalculate statuses only if something changed
      if (hasChanges) {
        await db.gamesDao.recalculateAllStatuses();
        ref.invalidate(backlogProvider);
        ref.invalidate(completedProvider);
      }

      state = const SyncState();
    } catch (e) {
      state = SyncState(status: SyncStatus.error, errorMessage: e.toString());
    }
  }
}

/// Auto-syncs on first launch if the local DB is empty.
final initialSyncProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  final games = await db.gamesDao.getAllGames();
  if (games.isEmpty) {
    await ref.read(syncStateProvider.notifier).sync();
  }
});
