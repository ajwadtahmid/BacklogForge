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

    // Preserve locked picks; only refill unlocked slots.
    final lockedPicks = state.picks
        .where((g) => state.lockedIds.contains(g.id))
        .toList();
    final slotsNeeded = 5 - lockedPicks.length;
    final pool = backlog.where((g) => !state.lockedIds.contains(g.id)).toList();
    final newPicks = _weightedSample(pool, slotsNeeded);

    // Rebuild: keep locked games in their original positions.
    final List<Game> finalPicks;
    if (lockedPicks.isEmpty || state.picks.isEmpty) {
      finalPicks = newPicks;
    } else {
      int newIdx = 0;
      final rebuilt = <Game>[];
      for (final existing in state.picks) {
        if (state.lockedIds.contains(existing.id)) {
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

    state = state.copyWith(picks: finalPicks, loading: false, spun: true);
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

  /// Weighted random sample without replacement.
  ///
  /// Score formula per game:
  ///   neglect = log(min(daysOwned, 365) + 1) / (hoursPlayed + 1)
  ///   aging   = +0.05 per full year owned beyond year 1, capped at 9 years (+0.45 max) for a total of 10 years
  ///   new     = +0.5 * exp(-daysOwned / 90)   ← boost for recently-bought games
  ///   recent  = +0.5 * exp(-daysSincePlayed / 90)  ← boost for recently-played games
  ///
  /// Clamped to 0.01 so every game has a non-zero chance.
  List<Game> _weightedSample(List<Game> pool, int n) {
    if (pool.isEmpty) return [];
    final rng = Random();
    final now = DateTime.now();

    final weighted = pool.map((g) {
      final daysOwned = now.difference(g.addedAt).inDays.toDouble();
      final hours = g.playtimeMinutes / 60.0;

      // Neglect score: capped at 365 days so very old games don't dominate.
      final clampedDays = daysOwned.clamp(0.0, 365.0);
      double score = log(clampedDays + 1) / (hours + 1);

      // Small aging bonus for games owned > 1 year, up to 10 years (+0.45 max).
      final extraYears = ((daysOwned - 365.0) / 365.0).clamp(0.0, 9.0);
      score += extraYears * 0.05;

      // New-purchase boost: prioritises recently-bought games.
      score += 0.5 * exp(-daysOwned / 90.0);

      // Recency boost: keeps recently-played games visible for 3 months.
      final lp = g.lastPlayedAt;
      if (lp != null) {
        final daysSincePlayed = now.difference(lp).inDays.toDouble();
        score += 0.5 * exp(-daysSincePlayed / 90.0);
      }

      return (game: g, weight: score.clamp(0.01, double.infinity));
    }).toList();

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
