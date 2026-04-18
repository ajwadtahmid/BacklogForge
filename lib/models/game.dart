import '../services/database/app_database.dart';

/// Returns the CDN URL for the game's header image from Steam.
extension GameArtwork on Game {
  String get artworkUrl => appId > 0
      ? 'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg'
      : 'https://placehold.co/460x215/2F2F2F/FFFFFF/png?text=Steam+Game'; // manually-added games have no Steam CDN artwork
}
