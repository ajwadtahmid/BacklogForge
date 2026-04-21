import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// How the Play Next screen selects games from the backlog.
enum FindMethod {
  /// Weighted random: neglected games and recently-played games score higher.
  shuffle,

  /// Games where the user is at least halfway through the essential estimate.
  almostDone,
}

class PlayNextState {
  const PlayNextState({
    this.picks = const [],
    this.method = FindMethod.shuffle,
    this.loading = false,
    this.spun = false,
  });
  final List<Game> picks;
  final FindMethod method;
  final bool loading;

  /// True once the user has spun at least once; prevents showing an empty list on first open.
  final bool spun;

  PlayNextState copyWith({
    List<Game>? picks,
    FindMethod? method,
    bool? loading,
    bool? spun,
  }) => PlayNextState(
    picks: picks ?? this.picks,
    method: method ?? this.method,
    loading: loading ?? this.loading,
    spun: spun ?? this.spun,
  );
}

class PlayNextNotifier extends Notifier<PlayNextState> {
  @override
  PlayNextState build() => const PlayNextState();

  void setMethod(FindMethod method) => state = state.copyWith(method: method);

  Future<void> spin() async {
    state = state.copyWith(loading: true, spun: false);
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId ?? '';
    final backlog = await ref
        .read(databaseProvider)
        .gamesDao
        .getBacklog(steamId);
    final picks = _pick(backlog, state.method);
    state = state.copyWith(picks: picks, loading: false, spun: true);
  }

  List<Game> _pick(List<Game> backlog, FindMethod method) {
    switch (method) {
      case FindMethod.shuffle:
        return _weightedSample(backlog, 3);

      case FindMethod.almostDone:
        // Return games where playtime has crossed 50 % of the essential estimate,
        // ordered by those closest to completion first.
        final eligible =
            backlog
                .where((g) => g.essentialHours != null && g.essentialHours! > 0)
                .map(
                  (g) => (
                    game: g,
                    ratio: (g.playtimeMinutes / 60.0) / g.essentialHours!,
                  ),
                )
                .where((e) => e.ratio >= 0.5)
                .toList()
              ..sort((a, b) => b.ratio.compareTo(a.ratio));
        return eligible.take(3).map((e) => e.game).toList();
    }
  }

  /// Weighted random sample without replacement (n picks from pool).
  ///
  /// Weight formula per game:
  ///   base  = log(daysOwned + 1) / (hoursPlayed + 1)   ← neglect score
  ///   bonus = +0.5 if lastPlayedAt is within the last 30 days           ← recency boost
  ///
  /// Clamped to 0.01 so every game has a non-zero chance of selection.
  List<Game> _weightedSample(List<Game> pool, int n) {
    if (pool.isEmpty) return [];
    final rng = Random();
    final now = DateTime.now();

    final weighted = pool.map((g) {
      final days = now.difference(g.addedAt).inDays.toDouble();
      final hours = g.playtimeMinutes / 60.0;
      double score = log(days + 1) / (hours + 1);

      final lp = g.lastPlayedAt;
      if (lp != null && now.difference(lp).inDays <= 30) {
        score += 0.5;
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
