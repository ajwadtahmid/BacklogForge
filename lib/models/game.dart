import '../services/database/app_database.dart';
import 'steam_game.dart';

extension GameArtwork on Game {
  /// Returns the display artwork URL for this game.
  /// Steam games use the Steam CDN header image; manually added games use
  /// the HLTB image stored at insert time, falling back to a placeholder.
  String get artworkUrl {
    if (appId > 0) return steamArtworkUrl(appId);
    return hltbImageUrl ??
        'https://placehold.co/460x215/2F2F2F/FFFFFF/png?text=No+Artwork';
  }
}
