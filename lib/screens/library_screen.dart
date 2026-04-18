import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/game_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger auto-sync on first launch (empty DB only).
    ref.watch(initialSyncProvider);

    final syncState = ref.watch(syncStateProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BacklogForge'),
          actions: [
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
                  onPressed: () =>
                      ref.read(syncStateProvider.notifier).sync(),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Backlog'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: const TabBarView(children: [BacklogTab(), CompletedTab()]),
      ),
    );
  }
}

class BacklogTab extends ConsumerWidget {
  const BacklogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesFuture = ref.watch(backlogProvider);
    return gamesFuture.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (games) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 16 / 9,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: games.length,
        itemBuilder: (_, i) => GameCard(game: games[i]),
      ),
    );
  }
}

class CompletedTab extends ConsumerWidget {
  const CompletedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesFuture = ref.watch(completedProvider);
    return gamesFuture.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (games) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 16 / 9,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: games.length,
        itemBuilder: (_, i) => GameCard(game: games[i]),
      ),
    );
  }
}
