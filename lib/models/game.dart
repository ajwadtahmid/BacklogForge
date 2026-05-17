import '../services/database/app_database.dart';
import 'steam_game.dart';
import 'play_style.dart';

/// Returns target hours for [game] under [style], falling back through the
/// available estimates if the preferred one is missing.
double? resolveTargetHours(Game game, PlayStyle style) => switch (style) {
      PlayStyle.extended => game.extendedHours ?? game.essentialHours,
      PlayStyle.completionist =>
        game.completionistHours ?? game.extendedHours ?? game.essentialHours,
      PlayStyle.essential => game.essentialHours,
    };

extension GameArtwork on Game {
  /// Returns the display artwork URL for this game.
  /// Steam games use the Steam CDN header image; manually added games use
  /// the HLTB image stored at insert time, falling back to a placeholder.
  String get artworkUrl {
    if (appId > 0) return steamArtworkUrl(appId);
    return hltbImageUrl ?? '/assets/artwork/no_artwork.png';
  }

  /// Hours target for the progress bar, resolved from the game's stored play style.
  /// Falls back through the chain if the preferred estimate is missing.
  double? get targetHours => resolveTargetHours(this, playStyle.toPlayStyle);

  /// Fallback target hours using priority: essential > extended > completionist.
  /// Used for display when playStyle-selected hours are unavailable.
  double? get targetHoursWithFallback =>
      essentialHours ?? extendedHours ?? completionistHours;
}
