import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../providers/game_actions_provider.dart'; // Adjust import as needed

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
                  if (game.rushedHours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: ((game.playtimeMinutes / 60) / game.rushedHours!)
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
