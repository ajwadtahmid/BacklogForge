import '../models/game_status.dart';
import '../services/database/app_database.dart';

/// Represents the completion time threshold the user prefers for marking games as completed.
enum CompletionThreshold { rushed, casually, completionist }

GameStatus calculateStatus(Game g, CompletionThreshold t) {
  if (g.manualOverride) {
    return g.status.toGameStatus; // always respect user choice
  }

  final target = _resolveTarget(g, t);

  if (target != null && (g.playtimeMinutes / 60) >= target) {
    return GameStatus.completed;
  }
  return GameStatus.backlog;
}

/// Returns the target hours for the preferred threshold, falling back
/// through casually -> rushed -> completionist if data is missing.
double? _resolveTarget(Game g, CompletionThreshold t) {
  final preferred = switch (t) {
    CompletionThreshold.rushed => g.rushedHours,
    CompletionThreshold.casually => g.casuallyHours,
    CompletionThreshold.completionist => g.completionistHours,
  };
  if (preferred != null) return preferred;

  // Fallback chain: casually -> rushed -> completionist.
  return g.casuallyHours ?? g.rushedHours ?? g.completionistHours;
}
