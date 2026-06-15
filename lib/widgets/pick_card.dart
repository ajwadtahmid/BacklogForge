import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';
import 'artwork_image.dart';
import '../util/ui_tokens.dart';

class PickCard extends StatelessWidget {
  const PickCard({
    super.key,
    required this.game,
    this.subtitle,
    this.estimatedDoneBy,
    this.locked = false,
    this.onToggleLock,
    this.onShowReason,
  });

  final Game game;

  /// Context line shown below the game name (e.g. "Not played in 42 days").
  final String? subtitle;

  /// "Est. done by [date]" line derived from the daily budget, if available.
  final String? estimatedDoneBy;

  final bool locked;
  final VoidCallback? onToggleLock;

  /// When non-null, shows an info button that calls this with the reason text.
  final VoidCallback? onShowReason;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: locked
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: () => context.push('/library/game/${game.id}', extra: game),
        child: Row(
          children: [
            ArtworkImage(
              url: game.artworkUrl,
              width: kArtworkPickW,
              height: kArtworkPickH,
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
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (estimatedDoneBy != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        estimatedDoneBy!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onShowReason != null)
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Why was this picked?',
                onPressed: onShowReason,
              ),
            if (onToggleLock != null)
              IconButton(
                icon: Icon(
                  locked ? Icons.lock : Icons.lock_open_outlined,
                  size: 20,
                  color: locked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: locked ? 'Unlock' : 'Lock this pick',
                onPressed: onToggleLock,
              ),
          ],
        ),
      ),
    );
  }
}
