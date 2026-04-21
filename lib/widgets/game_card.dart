import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../providers/game_actions_provider.dart';
import '../screens/game_detail_screen.dart';

/// A horizontal list row for a game, showing artwork, name, playtime progress,
/// and HLTB estimates. Swipe right to delete (manual games) or see lock
/// (Steam games); swipe left to change status.
///
/// Set [isInCompletedTab] = true for completed-tab rows so the left swipe
/// shows "Playing" (stays in completed) and "Backlog" instead of "Done".
class GameCard extends ConsumerWidget {
  final Game game;
  final bool isInCompletedTab;

  const GameCard({
    super.key,
    required this.game,
    this.isInCompletedTab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = game.status.toGameStatus == GameStatus.playing;
    final hoursPlayed = game.playtimeMinutes / 60.0;
    final target = game.targetHours;
    final progress =
        target != null ? (hoursPlayed / target).clamp(0.0, 1.0) : null;

    return Slidable(
      key: ValueKey(game.id),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.15,
        children: [
          if (game.appId < 0)
            SlidableAction(
              onPressed: (_) async {
                // Capture messenger before async gap to avoid deactivated context.
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
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
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
                  content: Text(
                    'Steam games cannot be deleted from your library',
                  ),
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
        extentRatio: 0.28,
        children: [
          // First action: context-aware based on current playing state.
          // Playing → offer to unmark it; not playing → offer to mark it.
          if (isPlaying && isInCompletedTab)
            // Re-playing a completed game → revert to completed.
            SlidableAction(
              onPressed: (ctx) async {
                try {
                  await ref
                      .read(gameActionsProvider)
                      .setStatus(game, GameStatus.completed);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
              backgroundColor: Colors.teal,
              icon: Icons.check_circle_outline,
              label: 'Unmark',
            )
          else if (isPlaying)
            // Playing in backlog → move back to backlog.
            SlidableAction(
              onPressed: (ctx) async {
                try {
                  await ref
                      .read(gameActionsProvider)
                      .setStatus(game, GameStatus.backlog);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
              icon: Icons.inbox,
              label: 'Unmark',
            )
          else
            // Not playing → offer to mark as playing.
            SlidableAction(
              onPressed: (ctx) async {
                try {
                  await ref.read(gameActionsProvider).setStatus(
                        game,
                        GameStatus.playing,
                        preserveCompletedAt: isInCompletedTab,
                      );
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
          // Second action: Done (backlog) or Backlog (completed).
          if (isInCompletedTab)
            SlidableAction(
              onPressed: (ctx) async {
                try {
                  await ref
                      .read(gameActionsProvider)
                      .setStatus(game, GameStatus.backlog);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to update status: $e')),
                    );
                  }
                }
              },
              icon: Icons.inbox,
              label: 'Backlog',
            )
          else
            SlidableAction(
              onPressed: (ctx) async {
                try {
                  await ref
                      .read(gameActionsProvider)
                      .setStatus(game, GameStatus.completed);
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
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameDetailScreen(game: game),
          ),
        ),
        child: Container(
          color: isPlaying
              ? Colors.green.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Hero tag matches the detail screen so the artwork flies across.
              Hero(
                tag: 'artwork_${game.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: game.artworkUrl,
                    width: 96,
                    height: 54,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 96,
                      height: 54,
                      color: Colors.grey[800],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 96,
                      height: 54,
                      color: Colors.grey[800],
                      child: const Icon(Icons.image_not_supported, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isPlaying)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Playing',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _playtimeLabel(hoursPlayed, target),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _playtimeLabel(double hoursPlayed, double? target) {
    final played = hoursPlayed < 1
        ? '${game.playtimeMinutes}m'
        : '${hoursPlayed.toStringAsFixed(1)}h';
    if (target == null) return '$played played';
    return '$played / ${target.toStringAsFixed(1)}h';
  }
}
