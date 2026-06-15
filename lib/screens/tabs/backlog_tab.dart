import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/game_status.dart';
import '../../providers/sort_provider.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/database/games_dao.dart';
import 'game_list_tab_shared.dart';

const _kFilterLabels = {
  LengthFilter.any: 'Any',
  LengthFilter.short: '< 10h',
  LengthFilter.medium: '10–30h',
  LengthFilter.long: '30h+',
  LengthFilter.noData: 'No data',
};

const _kBacklogSortModes = [
  (SortMode.alphabetical, 'A–Z'),
  (SortMode.progress, 'Progress'),
  (SortMode.shortest, 'Shortest'),
  (SortMode.longest, 'Longest'),
  (SortMode.neglected, 'Unplayed'),
  (SortMode.highestRated, 'Rated'),
];

class BacklogTab extends ConsumerStatefulWidget {
  const BacklogTab({super.key});

  @override
  ConsumerState<BacklogTab> createState() => _BacklogTabState();
}

class _BacklogTabState extends ConsumerState<BacklogTab>
    with GameListTabMixin<BacklogTab> {

  Future<void> _bulkComplete(List<Game> filtered) async {
    final selected =
        filtered.where((g) => selectedIds.contains(g.id)).toList();
    if (!await confirmBulk(selected.length, 'Mark as complete')) return;
    await ref.read(gameActionsProvider).bulkMarkCompleted(selected);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} marked complete');
    }
  }

  Future<void> _bulkMarkPlaying(List<Game> filtered) async {
    final selected =
        filtered.where((g) => selectedIds.contains(g.id)).toList();
    if (!await confirmBulk(selected.length, 'Mark as playing')) return;
    await ref.read(gameActionsProvider).bulkMarkPlaying(selected);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} marked as playing');
    }
  }

  Future<void> _bulkMarkNotPlaying(List<Game> filtered) async {
    final selected = filtered
        .where((g) => selectedIds.contains(g.id) && g.status == GameStatus.playing.name)
        .toList();
    if (!await confirmBulk(selected.length, 'Remove from playing')) return;
    await ref.read(gameActionsProvider).bulkMoveToBacklog(selected);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} removed from playing');
    }
  }

  Widget _buildSortChips(SortMode current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _kBacklogSortModes.map((e) {
          final (mode, label) = e;
          return ChoiceChip(
            label: Text(label),
            selected: current == mode,
            showCheckmark: false,
            onSelected: (_) => ref
                .read(backlogSortModeProvider.notifier)
                .set(mode),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChips(LengthFilter current) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: LengthFilter.values.map((f) {
          final selected = current == f;
          return FilterChip(
            label: Text(_kFilterLabels[f]!),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => ref
                .read(backlogFilterProvider.notifier)
                .set(selected ? LengthFilter.any : f),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExtraFilterChips(ExtraFilter current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _extraChip('Rated', ExtraFilter.rated, current),
          _extraChip('Has notes', ExtraFilter.withNotes, current),
        ],
      ),
    );
  }

  Widget _extraChip(String label, ExtraFilter f, ExtraFilter current) {
    final selected = current == f;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => ref
          .read(backlogExtraFilterProvider.notifier)
          .set(selected ? ExtraFilter.any : f),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortMode = ref.watch(backlogSortModeProvider);
    final filter = ref.watch(backlogFilterProvider);
    final extraFilter = ref.watch(backlogExtraFilterProvider);
    final gamesFuture = ref.watch(backlogSortedProvider);

    return buildGameListBody(
      gamesFuture: gamesFuture,
      searchHint: 'Search backlog…',
      emptyText: 'Your backlog is empty — add a game or sync with Steam',
      emptyIcon: Icons.inbox_outlined,
      extraControls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text('Sort & Filter', style: TextStyle(fontSize: 14)),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            childrenPadding: EdgeInsets.zero,
            children: [
              _buildSortChips(sortMode),
              _buildFilterChips(filter),
              _buildExtraFilterChips(extraFilter),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addToBacklog',
        onPressed: () => context.push('/library/search'),
        tooltip: 'Add game manually',
        child: const Icon(Icons.add),
      ),
      bulkActionBar: (filtered) => BulkActionBar(
        selectedCount: selectedIds.length,
        onCancel: cancelSelection,
      ),
    );
  }
}
