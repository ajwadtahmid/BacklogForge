import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sort_provider.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/database/games_dao.dart';
import '../../widgets/game_card.dart';
import 'game_list_tab_shared.dart';

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
        .where((g) => selectedIds.contains(g.id) && g.status == 'playing')
        .toList();
    if (!await confirmBulk(selected.length, 'Remove from playing')) return;
    await ref.read(gameActionsProvider).bulkStopReplaying(selected);
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
              (SortMode.shortest, 'Shortest playtime'),
              (SortMode.longest, 'Longest playtime'),
              (SortMode.mostPlayed, 'Most played'),
            ].map((e) {
              final (mode, label) = e;
              final isSelected = current == mode;
              return ListTile(
                leading: isSelected ? const Icon(Icons.check) : null,
                title: Text(label),
                selected: isSelected,
                onTap: () {
                  ref
                      .read(completedSortModeProvider.notifier)
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
        SortMode.shortest => 'Shortest',
        SortMode.longest => 'Longest',
        SortMode.mostPlayed => 'Played',
        SortMode.neglected => 'Unplayed',
      };

  @override
  Widget build(BuildContext context) {
    final sortMode = ref.watch(completedSortModeProvider);
    final gamesFuture = ref.watch(completedSortedProvider);

    return Column(
      children: [
        if (!selectionMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search completed…',
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
                  child: Text(
                      query.isEmpty ? 'No games completed' : 'No results'),
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
                          isInCompletedTab: true,
                        );
                      }
                      return GestureDetector(
                        key: ValueKey(game.id),
                        onLongPress: () => enterSelectionMode(game.id),
                        child: GameCard(game: game, isInCompletedTab: true),
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
                            ? () => _bulkStopReplaying(filtered)
                            : null,
                        primaryLabel: 'Move to Backlog',
                        primaryIcon: Icons.undo,
                        onPrimary: () => _bulkMoveToBacklog(filtered),
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
