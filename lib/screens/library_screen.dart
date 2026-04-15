import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../widgets/game_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Library')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        /// Responsive grid layout that adapts to screen width, showing game cards with artwork.
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
      ),
    );
  }
}
