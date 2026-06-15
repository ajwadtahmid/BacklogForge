import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/games_dao.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';
import 'theme_provider.dart'; // for sharedPrefsProvider

const _kBacklogSortKey = 'backlog_sort';
const _kCompletedSortKey = 'completed_sort';
const _kBacklogFilterKey = 'backlog_length_filter';
const _kBacklogExtraFilterKey = 'backlog_extra_filter';
const _kCompletedExtraFilterKey = 'completed_extra_filter';

/// Generic Riverpod notifier that persists an enum value to SharedPreferences.
class _PrefsEnumNotifier<T extends Enum> extends Notifier<T> {
  _PrefsEnumNotifier(this._key, this._values, this._default);

  final String _key;
  final List<T> _values;
  final T _default;

  @override
  T build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    return _values.asNameMap()[raw] ?? _default;
  }

  void set(T value) {
    state = value;
    ref.read(sharedPrefsProvider).setString(_key, value.name);
  }
}

class _BacklogSortNotifier extends _PrefsEnumNotifier<SortMode> {
  _BacklogSortNotifier()
      : super(_kBacklogSortKey, SortMode.values, SortMode.alphabetical);
}

class _CompletedSortNotifier extends _PrefsEnumNotifier<SortMode> {
  _CompletedSortNotifier()
      : super(_kCompletedSortKey, SortMode.values, SortMode.alphabetical);
}

class _BacklogFilterNotifier extends _PrefsEnumNotifier<LengthFilter> {
  _BacklogFilterNotifier()
      : super(_kBacklogFilterKey, LengthFilter.values, LengthFilter.any);
}

class _BacklogExtraFilterNotifier extends _PrefsEnumNotifier<ExtraFilter> {
  _BacklogExtraFilterNotifier()
      : super(_kBacklogExtraFilterKey, ExtraFilter.values, ExtraFilter.any);
}

class _CompletedExtraFilterNotifier extends _PrefsEnumNotifier<ExtraFilter> {
  _CompletedExtraFilterNotifier()
      : super(_kCompletedExtraFilterKey, ExtraFilter.values, ExtraFilter.any);
}

final backlogSortModeProvider =
    NotifierProvider<_BacklogSortNotifier, SortMode>(_BacklogSortNotifier.new);

final completedSortModeProvider = NotifierProvider<_CompletedSortNotifier, SortMode>(
    _CompletedSortNotifier.new);

final backlogFilterProvider = NotifierProvider<_BacklogFilterNotifier, LengthFilter>(
    _BacklogFilterNotifier.new);

final backlogExtraFilterProvider = NotifierProvider<_BacklogExtraFilterNotifier, ExtraFilter>(
    _BacklogExtraFilterNotifier.new);

final completedExtraFilterProvider =
    NotifierProvider<_CompletedExtraFilterNotifier, ExtraFilter>(
        _CompletedExtraFilterNotifier.new);

/// Reactive backlog list. Resubscribes to a new Drift watch stream whenever
/// [backlogSortModeProvider] or [backlogFilterProvider] changes.
final backlogSortedProvider = StreamProvider<List<Game>>((ref) {
  final steamId = ref.watch(authProvider).asData?.value.steamId;
  if (steamId == null) return Stream.value([]);
  final sortMode = ref.watch(backlogSortModeProvider);
  final filter = ref.watch(backlogFilterProvider);
  final extraFilter = ref.watch(backlogExtraFilterProvider);
  return ref.watch(databaseProvider).gamesDao.watchBacklogSorted(
      sortMode, steamId, filter: filter, extraFilter: extraFilter);
});

/// Reactive completed list. Resubscribes whenever [completedSortModeProvider] changes.
final completedSortedProvider = StreamProvider<List<Game>>((ref) {
  final steamId = ref.watch(authProvider).asData?.value.steamId;
  if (steamId == null) return Stream.value([]);
  final sortMode = ref.watch(completedSortModeProvider);
  final extraFilter = ref.watch(completedExtraFilterProvider);
  return ref.watch(databaseProvider).gamesDao.watchCompletedSorted(
      sortMode, steamId, extraFilter: extraFilter);
});

/// All games across every status — used by unified search.
final allGamesProvider = StreamProvider<List<Game>>((ref) {
  final steamId = ref.watch(authProvider).asData?.value.steamId;
  if (steamId == null) return Stream.value([]);
  return ref.watch(databaseProvider).gamesDao.watchAllGames(steamId);
});
