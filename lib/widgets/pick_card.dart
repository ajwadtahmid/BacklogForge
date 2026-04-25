import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/database/app_database.dart';
import '../models/game.dart';

class PickCard extends StatelessWidget {
  const PickCard({
    super.key,
    required this.game,
    this.subtitle,
    this.locked = false,
    this.onToggleLock,
  });

  final Game game;

  /// Context line shown below the game name (e.g. "Not played in 42 days").
  final String? subtitle;

  final bool locked;
  final VoidCallback? onToggleLock;

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
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onToggleLock != null)
              IconButton(
                icon: Icon(
                  locked ? Icons.lock : Icons.lock_open_outlined,
                  size: 20,
                  color: locked
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[500],
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
