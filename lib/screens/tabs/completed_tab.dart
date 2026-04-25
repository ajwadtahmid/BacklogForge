import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sort_provider.dart';
import '../../services/database/games_dao.dart';
import '../../widgets/game_card.dart';

class CompletedTab extends ConsumerStatefulWidget {
  const CompletedTab({super.key});

  @override
  ConsumerState<CompletedTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends ConsumerState<CompletedTab> {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search completed…',
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
                    _query.isEmpty ? 'No games completed' : 'No results',
                  ),
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    GameCard(game: filtered[i], isInCompletedTab: true),
              );
            },
          ),
        ),
      ],
    );
  }
}
