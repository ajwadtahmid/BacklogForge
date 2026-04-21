import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/games_dao.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Single notifier class reused for both backlog and completed sort modes.
class SortModeNotifier extends Notifier<SortMode> {
  @override
  SortMode build() => SortMode.alphabetical;

  void setSortMode(SortMode mode) => state = mode;
}

final backlogSortModeProvider =
    NotifierProvider<SortModeNotifier, SortMode>(SortModeNotifier.new);

final completedSortModeProvider =
    NotifierProvider<SortModeNotifier, SortMode>(SortModeNotifier.new);

/// Provides the backlog list sorted by the user's chosen [SortMode].
final backlogSortedProvider = FutureProvider<List<Game>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) return [];
  final sortMode = ref.watch(backlogSortModeProvider);
  final dao = ref.watch(databaseProvider).gamesDao;
  return dao.backlogSorted(sortMode, steamId);
});

/// Provides the completed list sorted by the user's chosen [SortMode].
final completedSortedProvider = FutureProvider<List<Game>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) return [];
  final sortMode = ref.watch(completedSortModeProvider);
  final dao = ref.watch(databaseProvider).gamesDao;
  return dao.completedSorted(sortMode, steamId);
});
