import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

enum FindMethod {
  /// Weighted random: neglected and recently-played games score higher.
  shuffle,

  /// Combined focused mode — shows either Progress or Quickest results.
  focused,
}

/// Sub-view for [FindMethod.focused].
enum FocusedView {
  /// Games ≥50% through the player's play-style target, closest to done first.
  progress,

  /// Games with the fewest hours remaining, sorted ascending.
  quickest,
}

class PlayNextState {
  const PlayNextState({
    this.picks = const [],
    this.method = FindMethod.shuffle,
    this.focusedView = FocusedView.progress,
    this.loading = false,
    this.spun = false,
    this.lockedIds = const {},
  });
  final List<Game> picks;
  final FindMethod method;

  /// Which focused sub-view is currently active (only meaningful when
  /// [method] == [FindMethod.focused]).
  final FocusedView focusedView;

  final bool loading;

  /// True once the user has triggered at least one result.
  final bool spun;

  /// IDs of picks the user has locked — preserved across shuffle respins.
  final Set<int> lockedIds;

  PlayNextState copyWith({
    List<Game>? picks,
    FindMethod? method,
    FocusedView? focusedView,
    bool? loading,
    bool? spun,
    Set<int>? lockedIds,
  }) => PlayNextState(
    picks: picks ?? this.picks,
    method: method ?? this.method,
    focusedView: focusedView ?? this.focusedView,
    loading: loading ?? this.loading,
    spun: spun ?? this.spun,
    lockedIds: lockedIds ?? this.lockedIds,
  );
}

class PlayNextNotifier extends Notifier<PlayNextState> {
  // Weight cache — invalidated whenever the backlog's content changes.
  String? _backlogFingerprint;
  Map<int, double> _weightCache = {};

  @override
  PlayNextState build() => const PlayNextState();

  void setMethod(FindMethod method) {
    if (state.method == method) return;
    state = state.copyWith(
      method: method,
      focusedView: FocusedView.progress,
      lockedIds: const {},
      picks: const [],
      spun: false,
    );
  }

  void toggleLock(int gameId) {
    final updated = Set<int>.from(state.lockedIds);
    if (updated.contains(gameId)) {
      updated.remove(gameId);
    } else {
      updated.add(gameId);
    }
    state = state.copyWith(lockedIds: updated);
  }

  Future<void> spin() async {
    if (state.method == FindMethod.focused) {
      // First press: load progress. Subsequent presses: swap to the other view.
      final nextView = !state.spun
          ? FocusedView.progress
          : (state.focusedView == FocusedView.progress
                ? FocusedView.quickest
                : FocusedView.progress);

      state = state.copyWith(
        loading: true,
        spun: false,
        focusedView: nextView,
        lockedIds:
            const {}, // locks don't carry over between deterministic views
      );

      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId ?? '';
      final backlog = await ref
          .read(databaseProvider)
          .gamesDao
          .getBacklog(steamId);
      final picks = _pickFocused(backlog, nextView, 5);
      state = state.copyWith(picks: picks, loading: false, spun: true);
      return;
    }

    // ── Shuffle mode ────────────────────────────────────────────────────────
    state = state.copyWith(loading: true, spun: false);
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId ?? '';
    final backlog = await ref
        .read(databaseProvider)
        .gamesDao
        .getBacklog(steamId);

    // Drop lock IDs for games that no longer exist in the backlog (e.g. deleted).
    final backlogIds = {for (final g in backlog) g.id};
    final validLockedIds = state.lockedIds.intersection(backlogIds);

    // Preserve valid locked picks; refill all other slots.
    final lockedPicks = state.picks
        .where((g) => validLockedIds.contains(g.id))
        .toList();
    final slotsNeeded = 5 - lockedPicks.length;
    final pool = backlog.where((g) => !validLockedIds.contains(g.id)).toList();
    final weights = _getOrBuildWeights(backlog);
    final newPicks = _weightedSample(pool, slotsNeeded, weights);

    // Rebuild: keep valid locked games in their original positions;
    // slots vacated by deleted locked games are filled from newPicks.
    final List<Game> finalPicks;
    if (lockedPicks.isEmpty || state.picks.isEmpty) {
      finalPicks = newPicks;
    } else {
      int newIdx = 0;
      final rebuilt = <Game>[];
      for (final existing in state.picks) {
        if (validLockedIds.contains(existing.id)) {
          rebuilt.add(existing);
        } else if (newIdx < newPicks.length) {
          rebuilt.add(newPicks[newIdx++]);
        }
      }
      while (newIdx < newPicks.length) {
        rebuilt.add(newPicks[newIdx++]);
      }
      finalPicks = rebuilt;
    }

    state = state.copyWith(
      picks: finalPicks,
      loading: false,
      spun: true,
      lockedIds: validLockedIds,
    );
  }

  List<Game> _pickFocused(List<Game> pool, FocusedView view, int n) {
    switch (view) {
      case FocusedView.progress:
        final eligible = <({Game game, double ratio})>[];
        for (final g in pool) {
          final target = g.targetHours ?? g.targetHoursWithFallback;
          if (target == null || target <= 0) continue;
          final ratio = (g.playtimeMinutes / 60.0) / target;
          if (ratio >= 0.5) eligible.add((game: g, ratio: ratio));
        }
        eligible.sort((a, b) => b.ratio.compareTo(a.ratio));
        return eligible.take(n).map((e) => e.game).toList();

      case FocusedView.quickest:
        final withData = <({Game game, double remaining})>[];
        for (final g in pool) {
          final target = g.targetHours ?? g.targetHoursWithFallback;
          if (target == null) continue;
          final remaining = target - (g.playtimeMinutes / 60.0);
          if (remaining > 0) withData.add((game: g, remaining: remaining));
        }
        withData.sort((a, b) => a.remaining.compareTo(b.remaining));
        return withData.take(n).map((e) => e.game).toList();
    }
  }

  /// Returns the cached weight map for [backlog], rebuilding only when the
  /// backlog's playtime or play-history has changed since the last call.
  Map<int, double> _getOrBuildWeights(List<Game> backlog) {
    final fp = _fingerprint(backlog);
    if (fp == _backlogFingerprint) return _weightCache;
    _backlogFingerprint = fp;
    _weightCache = _buildWeightMap(backlog);
    return _weightCache;
  }

  /// Cheap fingerprint over the fields that affect weight scores.
  static String _fingerprint(List<Game> games) {
    final buf = StringBuffer();
    for (final g in games) {
      buf
        ..write(g.id)
        ..write(':')
        ..write(g.playtimeMinutes)
        ..write(':')
        ..write(g.lastPlayedAt?.millisecondsSinceEpoch ?? 0)
        ..write(',');
    }
    return buf.toString();
  }

  /// Computes a weight for every game in [pool].
  ///
  /// Score formula:
  ///   neglect = log(min(daysOwned, 365) + 1) / (hoursPlayed + 1)
  ///   aging   = +0.05 per full year owned beyond year 1, capped at 9 years
  ///   new     = +0.5 * exp(-daysOwned / 90)   ← boost for recently-bought games
  ///   recent  = +0.5 * exp(-daysSincePlayed / 90)  ← boost for recently-played games
  ///
  /// Clamped to 0.01 so every game has a non-zero chance.
  static Map<int, double> _buildWeightMap(List<Game> pool) {
    final now = DateTime.now();
    final result = <int, double>{};
    for (final g in pool) {
      final daysOwned = now.difference(g.addedAt).inDays.toDouble();
      final hours = g.playtimeMinutes / 60.0;
      final clampedDays = daysOwned.clamp(0.0, 365.0);
      double score = log(clampedDays + 1) / (hours + 1);
      final extraYears = ((daysOwned - 365.0) / 365.0).clamp(0.0, 9.0);
      score += extraYears * 0.05;
      score += 0.5 * exp(-daysOwned / 90.0);
      final lp = g.lastPlayedAt;
      if (lp != null) {
        score += 0.5 * exp(-now.difference(lp).inDays.toDouble() / 90.0);
      }
      result[g.id] = score.clamp(0.01, double.infinity);
    }
    return result;
  }

  /// Weighted random sample without replacement from [pool], using pre-computed
  /// [weights]. Falls back to 0.01 for any game not found in the map.
  List<Game> _weightedSample(List<Game> pool, int n, Map<int, double> weights) {
    if (pool.isEmpty) return [];
    final rng = Random();
    final weighted = pool
        .map((g) => (game: g, weight: weights[g.id] ?? 0.01))
        .toList();

    final picks = <Game>[];
    final remaining = List.of(weighted);

    for (int i = 0; i < n && remaining.isNotEmpty; i++) {
      final total = remaining.fold(0.0, (sum, e) => sum + e.weight);
      double pick = rng.nextDouble() * total;
      int chosen = 0;
      for (int j = 0; j < remaining.length; j++) {
        pick -= remaining[j].weight;
        if (pick <= 0) {
          chosen = j;
          break;
        }
      }
      picks.add(remaining[chosen].game);
      remaining.removeAt(chosen);
    }

    return picks;
  }
}

final playNextProvider = NotifierProvider<PlayNextNotifier, PlayNextState>(
  PlayNextNotifier.new,
);
