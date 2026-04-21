import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../providers/game_actions_provider.dart';

/// A card widget displaying a game's cover art, name, and playtime progress.
/// Games currently being played are highlighted with a green tint.
/// Swipe horizontally to reveal Playing/Done action buttons.
class GameCard extends ConsumerWidget {
  final Game game;

  const GameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ValueKey(game.appId),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          if (game.appId < 0)
            SlidableAction(
              onPressed: (_) async {
                // Use the stable outer context, not the Slidable's ctx.
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Delete game?'),
                    content: Text('Remove "${game.name}" from your library?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref.read(gameActionsProvider).deleteGame(game);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            )
          else
            SlidableAction(
              onPressed: (_) => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Steam games cannot be deleted from your library'),
                  duration: Duration(seconds: 2),
                ),
              ),
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              icon: Icons.lock,
              label: 'Locked',
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (ctx) async {
              try {
                await ref.read(gameActionsProvider).setStatus(game, GameStatus.playing);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
            icon: Icons.play_arrow,
            label: 'Playing',
          ),
          SlidableAction(
            onPressed: (ctx) async {
              try {
                await ref.read(gameActionsProvider).setStatus(game, GameStatus.completed);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
            icon: Icons.check,
            label: 'Done',
          ),
        ],
      ),
      child: Card(
        // Highlight currently playing games with a subtle green background.
        color: game.status.toGameStatus == GameStatus.playing
            ? Colors.green.withValues(alpha: 0.12)
            : null,
        child: Column(
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: game.artworkUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (game.essentialHours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: ((game.playtimeMinutes / 60) / game.essentialHours!)
                            .clamp(0, 1),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
