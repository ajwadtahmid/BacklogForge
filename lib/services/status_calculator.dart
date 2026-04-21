import '../models/game_status.dart';
import '../services/database/app_database.dart';

enum CompletionThreshold { essential, extended, completionist }

/// Derives a game's computed status from its playtime and time-to-beat data.
/// Manual overrides bypass this calculation and return the stored status directly.
GameStatus calculateStatus(Game g, CompletionThreshold t) {
  if (g.manualOverride) {
    return g.status.toGameStatus;
  }

  final target = _resolveTarget(g, t);

  if (target != null && (g.playtimeMinutes / 60) >= target) {
    return GameStatus.completed;
  }
  return GameStatus.backlog;
}

/// Returns the target hours for the preferred threshold, falling back
/// through the remaining thresholds if the preferred data is missing.
double? _resolveTarget(Game g, CompletionThreshold t) {
  final preferred = switch (t) {
    CompletionThreshold.essential => g.essentialHours,
    CompletionThreshold.extended => g.extendedHours,
    CompletionThreshold.completionist => g.completionistHours,
  };
  if (preferred != null) return preferred;

  return g.essentialHours ?? g.extendedHours ?? g.completionistHours;
}
