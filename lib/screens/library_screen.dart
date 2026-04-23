import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/play_next_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/sort_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database/app_database.dart';
import '../services/database/games_dao.dart';
import '../models/game.dart';
import '../widgets/game_card.dart';
import 'manual_search_screen.dart';
import 'onboarding_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(initialSyncProvider);
    final syncState = ref.watch(syncStateProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BacklogForge'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add game manually',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
              ),
            ),
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: 'Toggle theme',
              onPressed: () async {
                final currentMode =
                    Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                await ref
                    .read(themeModeNotifierProvider.notifier)
                    .setTheme(currentMode);
              },
            ),
            if (syncState.status == SyncStatus.syncing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Tooltip(
                message: syncState.errorMessage ?? 'Sync with Steam',
                child: IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: syncState.status == SyncStatus.error
                        ? Colors.red
                        : null,
                  ),
                  onPressed: () => ref.read(syncStateProvider.notifier).sync(),
                ),
              ),
            Consumer(
              builder: (context, ref, _) {
                final authAsync = ref.watch(authProvider);
                return authAsync.whenOrNull(
                  data: (auth) {
                    final isGuest = auth.steamId == 'guest_user';
                    return IconButton(
                      icon: Icon(isGuest ? Icons.login : Icons.logout),
                      tooltip: isGuest ? 'Sign in with Steam' : 'Sign out',
                      onPressed: isGuest
                          ? () => showModalBottomSheet(
                                context: context,
                                builder: (_) => const SignInSheet(),
                              )
                          : () => ref.read(authProvider.notifier).signOut(),
                    );
                  },
                ) ?? IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: null,
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Backlog'),
              Tab(text: 'Completed'),
              Tab(text: 'Play Next'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [BacklogTab(), CompletedTab(), PlayNextTab(), StatsTab()],
        ),
      ),
    );
  }
}

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

  void _showSortSheetCompleted(
    BuildContext context,
    WidgetRef ref,
    SortMode current,
  ) {
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
                onPressed: () =>
                    _showSortSheetCompleted(context, ref, sortMode),
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

class PlayNextTab extends ConsumerWidget {
  const PlayNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playNextProvider);
    final notifier = ref.read(playNextProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MethodSelector(
            selected: state.method,
            onChanged: notifier.setMethod,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.loading ? null : notifier.spin,
            icon: const Icon(Icons.shuffle),
            label: Text(state.loading ? 'Finding...' : 'Find Games'),
          ),
          const SizedBox(height: 24),
          if (state.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.spun)
            _PicksSection(picks: state.picks, method: state.method),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.selected, required this.onChanged});
  final FindMethod selected;
  final ValueChanged<FindMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FindMethod>(
      segments: const [
        ButtonSegment(
          value: FindMethod.shuffle,
          icon: Icon(Icons.shuffle),
          label: Text('Shuffle'),
        ),
        ButtonSegment(
          value: FindMethod.almostDone,
          icon: Icon(Icons.flag),
          label: Text('Almost Done'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _PicksSection extends StatelessWidget {
  const _PicksSection({required this.picks, required this.method});
  final List<Game> picks;
  final FindMethod method;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) {
      final message = switch (method) {
        FindMethod.almostDone =>
          'No backlog games are halfway through. Start playing something first.',
        _ => 'Your backlog is empty.',
      };
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    final message = picks.length < 3
        ? 'Only ${picks.length} game${picks.length == 1 ? '' : 's'} matched.'
        : null;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                message,
                style: const TextStyle(color: Colors.amber),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: picks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  SizedBox(height: 100, child: _PickCard(game: picks[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 90,
            child: CachedNetworkImage(
              imageUrl: game.artworkUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (game.extendedHours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '~${game.extendedHours!.toStringAsFixed(1)}h to beat',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => GridView.count(
        crossAxisCount: isWideScreen ? 3 : 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: isWideScreen ? 2.5 : 1.4,
        children: [
          _StatCard(
            label: 'Games in Backlog',
            value: '${stats.backlogCount}',
            icon: Icons.inbox,
          ),
          _StatCard(
            label: 'Hours to Clear',
            value: stats.hoursRemaining.toStringAsFixed(0),
            icon: Icons.schedule,
          ),
          _StatCard(
            label: 'Currently Playing',
            value: '${stats.playingCount}',
            icon: Icons.play_circle_outline,
          ),
          _StatCard(
            label: 'Added This Month',
            value: '${stats.addedThisMonth}',
            icon: Icons.add_circle_outline,
          ),
          _StatCard(
            label: 'Completed This Month',
            value: '${stats.completedThisMonth}',
            icon: Icons.check_circle_outline,
          ),
          _CompletionGradeCard(
            percent: stats.completionPercent,
            grade: stats.grade,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionGradeCard extends StatelessWidget {
  const _CompletionGradeCard({required this.percent, required this.grade});
  final double percent;
  final String grade;

  Color _color() {
    if (grade == 'A+' || grade == 'A') return Colors.green;
    if (grade == 'B') return Colors.teal;
    if (grade == 'C') return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              grade,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _color(),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            const Text(
              'Library Completed',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
