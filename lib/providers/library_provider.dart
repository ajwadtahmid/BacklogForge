import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import '../services/steam_service.dart';
import '../services/app_logger.dart';
import 'database_provider.dart';
import 'auth_provider.dart';
import 'provider_invalidation.dart';

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
  final int? hltbCurrent;
  final int? hltbTotal;
  /// Human-readable post-sync notification (auto-completions, HLTB failures).
  final String? notification;
  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.hltbCurrent,
    this.hltbTotal,
    this.notification,
  });
}

/// Maps raw exceptions from the sync pipeline to user-friendly messages.
String _friendlySyncError(Object e) {
  final raw = e.toString();
  if (raw.contains('profile_private')) {
    return 'Steam profile is private — make it public to sync.';
  }
  if (raw.contains('steam_api_error') || raw.contains('steam_api_timeout')) {
    return 'Could not reach Steam. Please try again later.';
  }
  if (raw.contains('Not signed in')) return 'You are not signed in.';
  if (raw.contains('TimeoutException')) {
    return 'The server took too long to respond — it may be waking up. Please try again in a moment.';
  }
  if (raw.contains('SocketException') || raw.contains('network')) {
    return 'No internet connection. Please check your network.';
  }
  return 'Sync failed. Please try again.';
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

      final allGames = await db.gamesDao.getAllGames(steamId);
      final hltbResult = await db.gamesDao.fetchAllTimeToBeat(
        allGames,
        onProgress: (current, total) {
          state = SyncState(
            status: SyncStatus.syncing,
            hltbCurrent: current,
            hltbTotal: total,
          );
        },
      );

      // Always recalculate — status correctness matters more than skipping a
      // cheap pass. The recalculator already diffs and skips unchanged rows.
      final autoCompleted = await db.gamesDao.recalculateAllStatuses(steamId);
      invalidateLibraryProviders(ref);

      final parts = <String>[];
      if (autoCompleted > 0) {
        final s = autoCompleted == 1 ? 'game' : 'games';
        parts.add('$autoCompleted $s automatically marked completed based on playtime.');
      }
      if (hltbResult.failed > 0) {
        final s = hltbResult.failed == 1 ? 'game' : 'games';
        parts.add('HLTB data unavailable for ${hltbResult.failed} $s — tap a game to set hours manually.');
      }

      state = SyncState(
        notification: parts.isEmpty ? null : parts.join('\n'),
      );
    } catch (e, st) {
      AppLogger.instance.error('Sync failed', e, st);
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: _friendlySyncError(e),
      );
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
