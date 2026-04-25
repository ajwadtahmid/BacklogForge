import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sort_provider.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/database/games_dao.dart';
import '../../widgets/game_card.dart';
import 'game_list_tab_shared.dart';

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
        .where((g) => selectedIds.contains(g.id) && g.status == 'playing')
        .toList();
    if (!await confirmBulk(selected.length, 'Remove from playing')) return;
    await ref.read(gameActionsProvider).bulkMoveToBacklog(selected);
    if (mounted) {
      cancelSelection();
      showSnack('${selected.length} game${selected.length == 1 ? '' : 's'} removed from playing');
    }
  }

  void _showSortSheet(SortMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Sort by',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...[
              (SortMode.alphabetical, 'A-Z'),
              (SortMode.progress, 'Progress'),
              (SortMode.shortest, 'Shortest remaining'),
              (SortMode.longest, 'Longest remaining'),
              (SortMode.mostPlayed, 'Most played'),
              (SortMode.neglected, 'Unplayed'),
            ].map((e) {
              final (mode, label) = e;
              final isSelected = current == mode;
              return ListTile(
                leading: isSelected ? const Icon(Icons.check) : null,
                title: Text(label),
                selected: isSelected,
                onTap: () {
                  ref
                      .read(backlogSortModeProvider.notifier)
                      .setSortMode(mode);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SortMode mode) => switch (mode) {
        SortMode.alphabetical => 'A-Z',
        SortMode.progress => 'Progress',
        SortMode.shortest => 'Shortest remaining',
        SortMode.longest => 'Longest remaining',
        SortMode.mostPlayed => 'Played',
        SortMode.neglected => 'Unplayed',
      };

  @override
  Widget build(BuildContext context) {
    final sortMode = ref.watch(backlogSortModeProvider);
    final gamesFuture = ref.watch(backlogSortedProvider);

    return Column(
      children: [
        if (!selectionMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search backlog…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Text('Sort: ${_sortLabel(sortMode)}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort options',
                  onPressed: () => _showSortSheet(sortMode),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: gamesFuture.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (games) {
              final filtered = query.isEmpty || selectionMode
                  ? games
                  : games
                      .where((g) => g.name.toLowerCase().contains(query))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child:
                      Text(query.isEmpty ? 'No games in backlog' : 'No results'),
                );
              }

              return Stack(
                children: [
                  ListView.separated(
                    padding: selectionMode
                        ? const EdgeInsets.only(bottom: 72)
                        : null,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final game = filtered[i];
                      if (selectionMode) {
                        return SelectableGameRow(
                          key: ValueKey(game.id),
                          game: game,
                          selected: selectedIds.contains(game.id),
                          onTap: () => toggleSelect(game.id),
                        );
                      }
                      return GestureDetector(
                        key: ValueKey(game.id),
                        onLongPress: () => enterSelectionMode(game.id),
                        child: GameCard(game: game),
                      );
                    },
                  ),
                  if (selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: BulkActionBar(
                        selectedCount: selectedIds.length,
                        onCancel: cancelSelection,
                        onMarkPlaying: filtered.any((g) =>
                                selectedIds.contains(g.id) &&
                                g.status != 'playing')
                            ? () => _bulkMarkPlaying(filtered)
                            : null,
                        onMarkNotPlaying: filtered.any((g) =>
                                selectedIds.contains(g.id) &&
                                g.status == 'playing')
                            ? () => _bulkMarkNotPlaying(filtered)
                            : null,
                        primaryLabel: 'Mark Complete',
                        primaryIcon: Icons.check_circle_outline,
                        onPrimary: () => _bulkComplete(filtered),
                        onDelete: () => bulkDelete(filtered),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
