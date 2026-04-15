import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/steam_game.dart';

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});
  final SteamGame game;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CachedNetworkImage(
              imageUrl: game.artworkUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.videogame_asset),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
