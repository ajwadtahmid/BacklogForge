import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sort_provider.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              child: Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(
                'Sort: ${_sortLabel(sortMode)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort options',
                onPressed: () => _showSortSheet(context, ref, sortMode),
              ),
            ],
          ),
        ),
        Expanded(
          child: gamesFuture.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (games) {
              final filtered = _query.isEmpty
                  ? games
                  : games
                        .where((g) => g.name.toLowerCase().contains(_query))
                        .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty ? 'No games in backlog' : 'No results',
                  ),
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (context, i) => GameCard(game: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
