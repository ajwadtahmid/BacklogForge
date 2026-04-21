import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import '../services/steam_service.dart';
import 'database_provider.dart';
import 'auth_provider.dart';
import 'stats_provider.dart';
import 'sort_provider.dart';

/// Provides the current user's backlog (backlog + playing) games.
final backlogProvider = FutureProvider<List<Game>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) return [];
  final db = ref.watch(databaseProvider);
  return db.gamesDao.getBacklog(steamId);
});

/// Provides the current user's completed games.
final completedProvider = FutureProvider<List<Game>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) return [];
  final db = ref.watch(databaseProvider);
  return db.gamesDao.getCompleted(steamId);
});

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  const SyncState({this.status = SyncStatus.idle, this.errorMessage});
}

final syncStateProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Orchestrates a full sync: fetches Steam library, upserts games, pulls
/// missing HLTB data, then recalculates completion statuses.
class SyncNotifier extends Notifier<SyncState> {
  final _steamService = SteamService();

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
      bool hasChanges = false;

      final existing = await db.gamesDao.getAllGames(steamId);
      final oldPlaytime = {
        for (final g in existing) g.appId: g.playtimeMinutes,
      };

      final steamGames = await _steamService.getOwnedGames(steamId);
      final now = DateTime.now();

      // Upsert every Steam game: insert on first sync, update playtime on subsequent syncs.
      await db.transaction(() async {
        for (final game in steamGames) {
          await db.into(db.games).insert(
            GamesCompanion.insert(
              steamId: steamId,
              appId: game.appId,
              name: game.name,
              playtimeMinutes: Value(game.playtimeMinutes),
              lastPlayedAt: Value(game.lastPlayedAt),
              addedAt: now,
            ),
            onConflict: DoUpdate(
              (old) => GamesCompanion(
                name: Value(game.name),
                playtimeMinutes: Value(game.playtimeMinutes),
                lastPlayedAt: Value(game.lastPlayedAt),
              ),
              target: [db.games.appId, db.games.steamId],
            ),
          );
        }
      });

      for (final game in steamGames) {
        final old = oldPlaytime[game.appId];
        if (old == null || old != game.playtimeMinutes) {
          hasChanges = true;
          break;
        }
      }

      final allGames = await db.gamesDao.getAllGames(steamId);
      final newTimeToBeat = await db.gamesDao.fetchAllTimeToBeat(allGames);
      if (newTimeToBeat > 0) hasChanges = true;

      if (hasChanges) {
        await db.gamesDao.recalculateAllStatuses(steamId);
        ref.invalidate(backlogProvider);
        ref.invalidate(completedProvider);
        ref.invalidate(statsProvider);
        ref.invalidate(backlogSortedProvider);
        ref.invalidate(completedSortedProvider);
      }

      state = const SyncState();
    } catch (e) {
      state = SyncState(status: SyncStatus.error, errorMessage: e.toString());
    }
  }
}

/// Triggers an automatic sync on first launch if the local DB is empty for this user.
final initialSyncProvider = FutureProvider<void>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) return;
  final db = ref.watch(databaseProvider);
  final games = await db.gamesDao.getAllGames(steamId);
  if (games.isEmpty) {
    await ref.read(syncStateProvider.notifier).sync();
  }
});
