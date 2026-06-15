import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/sort_provider.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../util/search_match.dart';
import '../util/ui_tokens.dart';
import '../widgets/artwork_image.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _statusLabel(Game g) {
    final status = g.status.toGameStatus;
    return switch (status) {
      GameStatus.backlog => 'Backlog',
      GameStatus.playing => 'Playing',
      GameStatus.completed => 'Completed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allGamesAsync = ref.watch(allGamesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search all games…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: allGamesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (games) {
          if (_query.isEmpty) {
            return Center(
              child: Text(
                'Type to search your entire library',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }
          final results = games.where((g) => matchesGameName(g.name, _query)).toList();
          if (results.isEmpty) {
            return Center(
              child: Text(
                'No results for "$_query"',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final g = results[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ArtworkImage(url: g.artworkUrl, width: kArtworkSearchW, height: kArtworkSearchH),
                ),
                title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  _statusLabel(g),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                onTap: () => context.push('/library/game/${g.id}', extra: g),
              );
            },
          );
        },
      ),
    );
  }
}
