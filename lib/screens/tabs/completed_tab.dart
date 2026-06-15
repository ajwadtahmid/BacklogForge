import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_status.dart';
import '../../providers/sort_provider.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/database/games_dao.dart';
import 'game_list_tab_shared.dart';

const _kCompletedSortModes = [
  (SortMode.alphabetical, 'A–Z'),
  (SortMode.progress, 'Progress'),
  (SortMode.shortest, 'Shortest'),
  (SortMode.longest, 'Longest'),
  (SortMode.highestRated, 'Rated'),
];

class CompletedTab extends ConsumerStatefulWidget {
  const CompletedTab({super.key});

  @override
  ConsumerState<CompletedTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends ConsumerState<CompletedTab>
    with GameListTabMixin<CompletedTab> {

  Future<void> _bulkMoveToBacklog(List<Game> filtered) async {
    final selected =
        filtered.where((g) => selectedIds.contains(g.id)).toList();
    if (!await confirmBulk(selected.length, 'Move to backlog')) return;
    await ref.read(gameActionsProvider).bulkMoveToBacklog(selected);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} moved to backlog');
    }
  }

  Future<void> _bulkMarkPlaying(List<Game> filtered) async {
    final selected =
        filtered.where((g) => selectedIds.contains(g.id)).toList();
    if (!await confirmBulk(selected.length, 'Mark as playing')) return;
    await ref
        .read(gameActionsProvider)
        .bulkMarkPlaying(selected, preserveCompletedAt: true);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} marked as playing');
    }
  }

  Future<void> _bulkStopReplaying(List<Game> filtered) async {
    final selected = filtered
        .where((g) => selectedIds.contains(g.id) && g.status == GameStatus.playing.name)
        .toList();
    if (!await confirmBulk(selected.length, 'Remove from playing')) return;
    await ref.read(gameActionsProvider).bulkStopReplaying(selected);
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
        children: _kCompletedSortModes.map((e) {
          final (mode, label) = e;
          return ChoiceChip(
            label: Text(label),
            selected: current == mode,
            showCheckmark: false,
            onSelected: (_) => ref
                .read(completedSortModeProvider.notifier)
                .set(mode),
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
          .read(completedExtraFilterProvider.notifier)
          .set(selected ? ExtraFilter.any : f),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortMode = ref.watch(completedSortModeProvider);
    final extraFilter = ref.watch(completedExtraFilterProvider);
    final gamesFuture = ref.watch(completedSortedProvider);

    return buildGameListBody(
      gamesFuture: gamesFuture,
      searchHint: 'Search completed…',
      emptyText: 'No games completed yet',
      emptyIcon: Icons.emoji_events_outlined,
      isInCompletedTab: true,
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
              _buildExtraFilterChips(extraFilter),
            ],
          ),
        ],
      ),
      bulkActionBar: (filtered) => BulkActionBar(
        selectedCount: selectedIds.length,
        onCancel: cancelSelection,
      ),
    );
  }
}
