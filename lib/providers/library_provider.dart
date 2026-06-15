import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import '../services/hltb_sync_service.dart';
import '../services/steam_service.dart';
import '../services/sync_exception.dart';
import '../services/app_logger.dart';
import '../models/steam_game.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

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

/// Maps typed [SyncException]s (and unknown errors) to user-friendly messages.
String _friendlySyncError(Object e) {
  if (e is ProfilePrivateException) {
    return 'Steam profile is private — make it public to sync.';
  }
  if (e is SteamApiException) {
    return 'Could not reach Steam. Please try again later.';
  }
  if (e is NotSignedInException) return 'You are not signed in.';
  if (e is ServerTimeoutException) {
    return 'The server took too long to respond — it may be waking up. Please try again in a moment.';
  }
  if (e is NetworkException) {
    return 'No internet connection. Please check your network.';
  }
  if (e is HltbSearchException || e is HltbLookupException) {
    return 'Could not reach the HLTB server. Please try again later.';
  }
  return 'Sync failed. Please try again.';
}

final syncStateProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Orchestrates a full sync: fetches Steam library, upserts games, pulls
/// missing HLTB data, then recalculates completion statuses.
class SyncNotifier extends Notifier<SyncState> {
  final _steamService = SteamService();
  final _hltbSync = HltbSyncService();
  Timer? _errorClearTimer;

  @override
  SyncState build() => const SyncState();

  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;
    state = const SyncState(status: SyncStatus.syncing);

    try {
      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId;
      if (steamId == null) throw const NotSignedInException();

      final db = ref.read(databaseProvider);
      final steamGames = await _steamService.getOwnedGames(steamId);

      await _upsertSteamGames(db, steamGames, steamId);

      final allGames = await db.gamesDao.getAllGames(steamId);
      final hltbResult = await _hltbSync.fetchAllTimeToBeat(
        db.gamesDao,
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
      state = SyncState(notification: _buildSyncNotification(autoCompleted, hltbResult));
    } catch (e, st) {
      AppLogger.instance.error('Sync failed', e, st);
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: _friendlySyncError(e),
      );
      // Auto-clear after 10 s so the error doesn't persist indefinitely in Settings.
      // Cancel any previous timer so rapid re-sync failures don't clear prematurely.
      _errorClearTimer?.cancel();
      _errorClearTimer = Timer(const Duration(seconds: 10), () {
        if (state.status == SyncStatus.error) state = const SyncState();
      });
    }
  }

  static Future<void> _upsertSteamGames(
    AppDatabase db,
    List<SteamGame> steamGames,
    String steamId,
  ) async {
    final now = DateTime.now();
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
  }

  static String? _buildSyncNotification(
    int autoCompleted,
    ({int fetched, int failed}) hltbResult,
  ) {
    final parts = <String>[];
    if (autoCompleted > 0) {
      final s = autoCompleted == 1 ? 'game' : 'games';
      parts.add('$autoCompleted $s automatically marked completed based on playtime.');
    }
    if (hltbResult.failed > 0) {
      final s = hltbResult.failed == 1 ? 'game' : 'games';
      parts.add('HLTB data unavailable for ${hltbResult.failed} $s — tap a game to set hours manually.');
    }
    return parts.isEmpty ? null : parts.join('\n');
  }
}

/// Fires a background sync every 2 hours while the app is running and the user
/// is signed in. Watch this provider in the root widget so the timer lives for
/// the full app lifetime. The SyncNotifier already guards against concurrent syncs.
final backgroundSyncProvider = Provider<void>((ref) {
  final timer = Timer.periodic(const Duration(hours: 2), (_) {
    final auth = ref.read(authProvider).asData?.value;
    if (auth == null || auth.steamId == AuthNotifier.guestSteamId) return;
    if (ref.read(syncStateProvider).status == SyncStatus.syncing) return;
    ref.read(syncStateProvider.notifier).sync();
  });
  ref.onDispose(timer.cancel);
});

/// Triggers an automatic sync on first launch if the local DB is empty for this user.
final initialSyncProvider = FutureProvider<void>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null || steamId == AuthNotifier.guestSteamId) return;
  final db = ref.watch(databaseProvider);
  final games = await db.gamesDao.getAllGames(steamId);
  if (games.isEmpty) {
    await ref.read(syncStateProvider.notifier).sync();
  }
});
