import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../providers/game_actions_provider.dart';
import '../providers/daily_budget_provider.dart';
import '../theme.dart';
import '../util/date_format.dart';
import '../util/ui_tokens.dart';
import 'artwork_image.dart';

/// A horizontal list row for a game, showing artwork, name, playtime progress,
/// and HLTB estimates. Swipe right to delete (manual games) or see lock
/// (Steam games); swipe left to change status.
///
/// On desktop (pointer/hover capable devices), hovering over the row reveals
/// quick-action icon buttons so users don't need to discover swipe gestures.
/// Right-click opens the full context menu (handled by the parent tab).
///
/// Set [isInCompletedTab] = true for completed-tab rows so the left swipe and
/// hover actions show "Playing" (stays in completed) and "Backlog" instead of "Done".
class GameCard extends ConsumerStatefulWidget {
  final Game game;
  final bool isInCompletedTab;

  const GameCard({
    super.key,
    required this.game,
    this.isInCompletedTab = false,
  });

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> {
  Game get game => widget.game;
  bool get isInCompletedTab => widget.isInCompletedTab;

  Future<void> _setStatus(GameStatus next, {bool preserveCompletedAt = false}) async {
    try {
      HapticFeedback.lightImpact();
      await ref.read(gameActionsProvider).setStatus(
        game, next, preserveCompletedAt: preserveCompletedAt,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete game?'),
        content: Text('Remove "${game.name}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(gameActionsProvider).deleteGame(game);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPlaying = game.status.toGameStatus == GameStatus.playing;
    final hoursPlayed = game.playtimeMinutes / 60.0;
    final target = game.displayTargetHours;
    final progress =
        target != null ? (hoursPlayed / target).clamp(0.0, 1.0) : null;
    final budget = ref.watch(dailyBudgetProvider).asData?.value ?? 0.0;

    return Slidable(
      key: ValueKey(game.id),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.15,
        children: [
          if (game.appId < 0)
            SlidableAction(
              onPressed: (_) => _confirmDelete(),
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
              icon: Icons.delete_outline,
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
              backgroundColor: cs.surfaceContainerHigh,
              foregroundColor: cs.onSurfaceVariant,
              icon: Icons.lock_outline,
              label: 'Locked',
            ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        children: [
          if (isPlaying && isInCompletedTab)
            SlidableAction(
              onPressed: (_) => _setStatus(GameStatus.completed),
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              icon: Icons.check_circle_outline,
              label: 'Unmark',
            )
          else if (isPlaying)
            SlidableAction(
              onPressed: (_) => _setStatus(GameStatus.backlog),
              backgroundColor: cs.surfaceContainerHigh,
              foregroundColor: cs.onSurface,
              icon: Icons.inbox_outlined,
              label: 'Unmark',
            )
          else
            SlidableAction(
              onPressed: (_) => _setStatus(
                GameStatus.playing,
                preserveCompletedAt: isInCompletedTab,
              ),
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              icon: Icons.play_arrow_outlined,
              label: 'Playing',
            ),
          if (isInCompletedTab)
            SlidableAction(
              onPressed: (_) => _setStatus(GameStatus.backlog),
              backgroundColor: cs.surfaceContainerHigh,
              foregroundColor: cs.onSurface,
              icon: Icons.inbox_outlined,
              label: 'Backlog',
            )
          else
            SlidableAction(
              onPressed: (_) => _setStatus(GameStatus.completed),
              backgroundColor: cs.tertiaryContainer,
              foregroundColor: cs.onTertiaryContainer,
              icon: Icons.check_outlined,
              label: 'Done',
            ),
        ],
      ),
      child: InkWell(
          onTap: () => context.push('/library/game/${game.id}', extra: game),
          child: Semantics(
            label: '${game.name}. ${_playtimeSemanticsLabel(hoursPlayed, target)}.'
                '${isPlaying ? ' Currently playing.' : ''}',
            child: Container(
              color: isPlaying ? kColorPlayingBg : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'artwork_${game.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ArtworkImage(
                        url: game.artworkUrl,
                        width: kArtworkCardW,
                        height: kArtworkCardH,
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
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isPlaying)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kColorPlayingBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: kColorPlaying.withValues(alpha: 0.4),
                                      width: 0.5),
                                ),
                                child: const Text(
                                  'Playing',
                                  style: TextStyle(
                                    color: kColorPlaying,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _playtimeLabel(hoursPlayed, target),
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(3),
                            color: progressColor(progress, cs),
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ],
                        if (target != null &&
                            budget > 0 &&
                            progress != null &&
                            progress < 1.0) ...[
                          const SizedBox(height: 3),
                          Text(
                            estimatedDoneByLabel(target - hoursPlayed, budget) ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
    final pct = ((hoursPlayed / target) * 100).clamp(0.0, 100.0).round();
    return '$played / ${target.toStringAsFixed(1)}h · $pct%';
  }

  // Plain-text label for screen-reader semantics (no symbols).
  String _playtimeSemanticsLabel(double hoursPlayed, double? target) {
    final playedStr = hoursPlayed < 1
        ? '${game.playtimeMinutes} minutes played'
        : '${hoursPlayed.toStringAsFixed(1)} hours played';
    if (target == null) return playedStr;
    final pct = ((hoursPlayed / target) * 100).clamp(0.0, 100.0).round();
    return '$playedStr of ${target.toStringAsFixed(1)} hours, $pct percent complete';
  }
}
