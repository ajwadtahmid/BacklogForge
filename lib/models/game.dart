import '../services/database/app_database.dart';
import 'steam_game.dart';
import 'play_style.dart';

/// Returns target hours for [game] under [style].
/// Intentionally no cross-style fallback for `essential` — used by the UI
/// progress bar where showing "no data" is preferable to silently using a
/// longer estimate. `_resolveTarget` in status_calculator uses a full fallback
/// chain for auto-complete so it never misses a completable game.
double? resolveTargetHours(Game game, PlayStyle style) => switch (style) {
      PlayStyle.extended => game.extendedHours ?? game.essentialHours,
      PlayStyle.completionist =>
        game.completionistHours ?? game.extendedHours ?? game.essentialHours,
      PlayStyle.essential => game.essentialHours,
    };

extension GameArtwork on Game {
  /// Returns the display artwork URL for this game, or null for manual games
  /// with no HLTB image (ArtworkImage renders the bundled placeholder on null).
  String? get artworkUrl {
    if (appId > 0) return steamArtworkUrl(appId);
    return hltbImageUrl;
  }

  /// Play-style-resolved target hours, falling back to any available estimate.
  double? get displayTargetHours =>
      resolveTargetHours(this, playStyle.toPlayStyle) ??
      essentialHours ??
      extendedHours ??
      completionistHours;
}
