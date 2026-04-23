import '../services/database/app_database.dart';
import 'steam_game.dart';
import 'play_style.dart';

extension GameArtwork on Game {
  /// Returns the display artwork URL for this game.
  /// Steam games use the Steam CDN header image; manually added games use
  /// the HLTB image stored at insert time, falling back to a placeholder.
  String get artworkUrl {
    if (appId > 0) return steamArtworkUrl(appId);
    return hltbImageUrl ??
        'https://placehold.co/460x215/2F2F2F/FFFFFF/png?text=No+Artwork';
  }

  /// Hours target for the progress bar, resolved from the game's stored play style.
  /// Falls back through the chain if the preferred estimate is missing.
  double? get targetHours => switch (playStyle.toPlayStyle) {
        PlayStyle.extended =>
          extendedHours ?? essentialHours,
        PlayStyle.completionist =>
          completionistHours ?? extendedHours ?? essentialHours,
        PlayStyle.essential => essentialHours,
      };

  /// Fallback target hours using priority: essential > extended > completionist.
  /// Used for display when playStyle-selected hours are unavailable.
  double? get targetHoursWithFallback =>
    essentialHours ?? extendedHours ?? completionistHours;
}
