import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sort_provider.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/database/games_dao.dart';
import '../../widgets/game_card.dart';

class BacklogTab extends ConsumerStatefulWidget {
  const BacklogTab({super.key});

  @override
  ConsumerState<BacklogTab> createState() => _BacklogTabState();
}

class _BacklogTabState extends ConsumerState<BacklogTab> {
  final _searchController = TextEditingController();
  String _query = '';

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(int gameId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(gameId);
    });
  }

  void _toggleSelect(int gameId) {
    setState(() {
      if (_selectedIds.contains(gameId)) {
        _selectedIds.remove(gameId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(gameId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkComplete(List<Game> allGames) async {
    final selected = allGames.where((g) => _selectedIds.contains(g.id)).toList();
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(gameActionsProvider).bulkMarkCompleted(selected);
    if (mounted) {
      _cancelSelection();
      messenger.showSnackBar(
        SnackBar(content: Text('${selected.length} game${selected.length == 1 ? '' : 's'} marked complete')),
      );
    }
  }

  Future<void> _bulkMarkPlaying(List<Game> allGames) async {
    final selected = allGames.where((g) => _selectedIds.contains(g.id)).toList();
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(gameActionsProvider).bulkMarkPlaying(selected);
    if (mounted) {
      _cancelSelection();
      messenger.showSnackBar(
        SnackBar(content: Text('${selected.length} game${selected.length == 1 ? '' : 's'} marked as playing')),
      );
    }
  }

  Future<void> _bulkMarkNotPlaying(List<Game> allGames) async {
    final selected = allGames
        .where((g) => _selectedIds.contains(g.id) && g.status == 'playing')
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(gameActionsProvider).bulkMoveToBacklog(selected);
    if (mounted) {
      _cancelSelection();
      messenger.showSnackBar(
        SnackBar(content: Text('${selected.length} game${selected.length == 1 ? '' : 's'} removed from playing')),
      );
    }
  }

  Future<void> _bulkDelete(List<Game> allGames) async {
    final selected = allGames.where((g) => _selectedIds.contains(g.id)).toList();
    final steamCount = selected.where((g) => g.appId >= 0).length;
    final deletable = selected.where((g) => g.appId < 0).length;
    final messenger = ScaffoldMessenger.of(context);

    final message = steamCount > 0
        ? 'Delete $deletable game${deletable == 1 ? '' : 's'}? ($steamCount Steam game${steamCount == 1 ? '' : 's'} will be skipped)'
        : 'Delete $deletable game${deletable == 1 ? '' : 's'}?';

    if (deletable == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Steam games cannot be deleted')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete games?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final skipped = await ref.read(gameActionsProvider).bulkDelete(selected);
      _cancelSelection();
      if (skipped > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text('$skipped Steam game${skipped == 1 ? '' : 's'} skipped')),
        );
      }
    }
  }

  void _showSortSheet(BuildContext context, WidgetRef ref, SortMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Sort by', style: Theme.of(context).textTheme.titleLarge),
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
                  ref.read(backlogSortModeProvider.notifier).setSortMode(mode);
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
        if (!_selectionMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search backlog…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Text('Sort: ${_sortLabel(sortMode)}', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort options',
                  onPressed: () => _showSortSheet(context, ref, sortMode),
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
              final filtered = _query.isEmpty || _selectionMode
                  ? games
                  : games.where((g) => g.name.toLowerCase().contains(_query)).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(_query.isEmpty ? 'No games in backlog' : 'No results'),
                );
              }

              return Stack(
                children: [
                  ListView.separated(
                    padding: _selectionMode ? const EdgeInsets.only(bottom: 72) : null,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final game = filtered[i];
                      if (_selectionMode) {
                        final selected = _selectedIds.contains(game.id);
                        return _SelectableRow(
                          game: game,
                          selected: selected,
                          onTap: () => _toggleSelect(game.id),
                        );
                      }
                      return GestureDetector(
                        onLongPress: () => _enterSelectionMode(game.id),
                        child: GameCard(game: game),
                      );
                    },
                  ),
                  if (_selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _BulkActionBar(
                        selectedCount: _selectedIds.length,
                        onCancel: _cancelSelection,
                        onMarkPlaying: () => _bulkMarkPlaying(filtered),
                        onMarkNotPlaying: filtered.any(
                          (g) => _selectedIds.contains(g.id) && g.status == 'playing',
                        )
                            ? () => _bulkMarkNotPlaying(filtered)
                            : null,
                        primaryLabel: 'Mark Complete',
                        primaryIcon: Icons.check_circle_outline,
                        onPrimary: () => _bulkComplete(filtered),
                        onDelete: () => _bulkDelete(filtered),
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

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  final Game game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onTap()),
            Expanded(child: AbsorbPointer(child: GameCard(game: game))),
          ],
        ),
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onMarkPlaying,
    this.onMarkNotPlaying,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onMarkPlaying;
  final VoidCallback? onMarkNotPlaying;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: onCancel,
              ),
              Text(
                '$selectedCount selected',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Mark as Playing',
                onPressed: enabled ? onMarkPlaying : null,
              ),
              if (onMarkNotPlaying != null)
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline),
                  tooltip: 'Mark as Not Playing',
                  onPressed: onMarkNotPlaying,
                ),
              IconButton(
                icon: Icon(primaryIcon),
                tooltip: primaryLabel,
                onPressed: enabled ? onPrimary : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                color: enabled ? Colors.red[400] : null,
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
