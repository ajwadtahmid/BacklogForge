import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
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
    this.scoreReasons = const {},
    this.progressThreshold = 0.50,
    this.focusedDisplayCount = AppConstants.kPickCount,
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

  /// Human-readable score explanation per game ID (shuffle mode only).
  final Map<int, String> scoreReasons;

  /// Minimum completion ratio (0.50–0.95) for the "Almost Done" view.
  final double progressThreshold;

  /// How many focused picks to display — grows by [AppConstants.kPickCount]
  /// each time the user taps "Load more".
  final int focusedDisplayCount;

  PlayNextState copyWith({
    List<Game>? picks,
    FindMethod? method,
    FocusedView? focusedView,
    bool? loading,
    bool? spun,
    Set<int>? lockedIds,
    Map<int, String>? scoreReasons,
    double? progressThreshold,
    int? focusedDisplayCount,
  }) => PlayNextState(
    picks: picks ?? this.picks,
    method: method ?? this.method,
    focusedView: focusedView ?? this.focusedView,
    loading: loading ?? this.loading,
    spun: spun ?? this.spun,
    lockedIds: lockedIds ?? this.lockedIds,
    scoreReasons: scoreReasons ?? this.scoreReasons,
    progressThreshold: progressThreshold ?? this.progressThreshold,
    focusedDisplayCount: focusedDisplayCount ?? this.focusedDisplayCount,
  );
}

class PlayNextNotifier extends Notifier<PlayNextState> {
  /// Games played within this window receive a decaying neglect penalty.
  static const double _kNeglectDecayDays = 90.0;

  /// Neglect score is capped at this many days to prevent runaway weighting.
  static const double _kMaxNeglectDays = 365.0;

  /// Extra weight added per full year owned beyond the first (capped at 9 years).
  static const double _kAgingRatePerYear = 0.05;

  /// Flat boost applied to games added within the last [_kNeglectDecayDays] days.
  static const double _kRecencyBoost = 0.5;

  // Weight cache — invalidated whenever the backlog's content changes.
  int? _backlogFingerprint;
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
    // Homestretch auto-loads on selection — the tabs are the primary control.
    if (method == FindMethod.focused) spin();
  }

  /// Switches the focused sub-view and immediately re-fetches picks.
  void setFocusedView(FocusedView view) {
    if (state.focusedView == view && state.spun) return;
    _focusedSpin(targetView: view);
  }

  /// Updates the displayed threshold value immediately (no re-spin).
  void updateProgressThreshold(double value) {
    state = state.copyWith(progressThreshold: value);
  }

  /// Re-spins with the current threshold (called when the slider is released).
  void applyProgressThreshold() {
    if (state.spun && state.method == FindMethod.focused) {
      _focusedSpin(targetView: state.focusedView);
    }
  }

  /// Shows [AppConstants.kPickCount] more games in the focused list.
  void loadMoreFocused() {
    state = state.copyWith(
      focusedDisplayCount: state.focusedDisplayCount + AppConstants.kPickCount,
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
      await _focusedSpin();
    } else {
      await _shuffleSpin();
    }
  }

  Future<void> _focusedSpin({FocusedView? targetView}) async {
    // If a specific view is requested, use it; otherwise first press → progress,
    // subsequent presses → toggle to the other view.
    final nextView = targetView ?? (!state.spun
        ? FocusedView.progress
        : (state.focusedView == FocusedView.progress
              ? FocusedView.quickest
              : FocusedView.progress));

    state = state.copyWith(
      loading: true,
      spun: false,
      focusedView: nextView,
      lockedIds: const {}, // locks don't carry over between deterministic views
      focusedDisplayCount: AppConstants.kPickCount, // reset pagination on every spin
    );

    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId ?? '';
    final backlog = await ref.read(databaseProvider).gamesDao.getBacklog(steamId);
    final picks = _pickFocused(backlog, nextView, state.progressThreshold);
    state = state.copyWith(picks: picks, loading: false, spun: true);
  }

  Future<void> _shuffleSpin() async {
    state = state.copyWith(loading: true, spun: false);
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId ?? '';
    final backlog = await ref.read(databaseProvider).gamesDao.getBacklog(steamId);

    // Drop lock IDs for games that no longer exist in the backlog (e.g. deleted).
    final backlogIds = {for (final g in backlog) g.id};
    final validLockedIds = state.lockedIds.intersection(backlogIds);

    // Preserve valid locked picks; refill all other slots.
    final lockedPicks = state.picks.where((g) => validLockedIds.contains(g.id)).toList();
    final slotsNeeded = AppConstants.kPickCount - lockedPicks.length;
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

    final reasons = _buildScoreReasons(finalPicks, weights);
    state = state.copyWith(
      picks: finalPicks,
      loading: false,
      spun: true,
      lockedIds: validLockedIds,
      scoreReasons: reasons,
    );
  }

  /// Generates a human-readable score breakdown for each picked game.
  static Map<int, String> _buildScoreReasons(
    List<Game> picks,
    Map<int, double> weights,
  ) {
    final now = DateTime.now();
    final reasons = <int, String>{};
    for (final g in picks) {
      final daysOwned = now.difference(g.addedAt).inDays;
      final hours = g.playtimeMinutes / 60.0;
      final lp = g.lastPlayedAt;
      final daysSincePlayed = lp != null ? now.difference(lp).inDays : null;
      final score = weights[g.id] ?? 0.0;

      final lines = <String>[];
      lines.add('Score: ${score.toStringAsFixed(2)}');
      lines.add('Owned for: $daysOwned day${daysOwned == 1 ? '' : 's'}');
      lines.add('Playtime: ${hours.toStringAsFixed(1)}h');
      if (daysSincePlayed != null) {
        lines.add('Last played: $daysSincePlayed day${daysSincePlayed == 1 ? '' : 's'} ago');
      } else {
        lines.add('Last played: never');
      }

      reasons[g.id] = lines.join('\n');
    }
    return reasons;
  }

  List<Game> _pickFocused(List<Game> pool, FocusedView view, double progressThreshold) {
    switch (view) {
      case FocusedView.progress:
        final eligible = <({Game game, double ratio})>[];
        for (final g in pool) {
          final target = g.displayTargetHours;
          if (target == null || target <= 0) continue;
          final ratio = (g.playtimeMinutes / 60.0) / target;
          if (ratio >= progressThreshold) {
            eligible.add((game: g, ratio: ratio));
          }
        }
        eligible.sort((a, b) => b.ratio.compareTo(a.ratio));
        return eligible.map((e) => e.game).toList();

      case FocusedView.quickest:
        final withData = <({Game game, double remaining})>[];
        for (final g in pool) {
          final target = g.displayTargetHours;
          if (target == null) continue;
          final remaining = target - (g.playtimeMinutes / 60.0);
          if (remaining > 0) withData.add((game: g, remaining: remaining));
        }
        withData.sort((a, b) => a.remaining.compareTo(b.remaining));
        return withData.map((e) => e.game).toList();
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
  static int _fingerprint(List<Game> games) => Object.hashAll(
        games.map((g) => Object.hash(
              g.id,
              g.playtimeMinutes,
              g.lastPlayedAt?.millisecondsSinceEpoch ?? 0,
            )),
      );

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
      final clampedDays = daysOwned.clamp(0.0, _kMaxNeglectDays);
      double score = log(clampedDays + 1) / (hours + 1);
      final extraYears = ((daysOwned - _kMaxNeglectDays) / _kMaxNeglectDays).clamp(0.0, 9.0);
      score += extraYears * _kAgingRatePerYear;
      score += _kRecencyBoost * exp(-daysOwned / _kNeglectDecayDays);
      final lp = g.lastPlayedAt;
      if (lp != null) {
        score += _kRecencyBoost * exp(-now.difference(lp).inDays.toDouble() / _kNeglectDecayDays);
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
      // Default to last element so floating-point rounding never leaves chosen unset.
      int chosen = remaining.length - 1;
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
