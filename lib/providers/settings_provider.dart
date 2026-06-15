import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Reactively emits the current user's settings row whenever it changes.
/// Emits null when no user is signed in.
final settingsStreamProvider = StreamProvider<AppSetting?>((ref) {
  final auth = ref.watch(authProvider).asData?.value;
  final steamId = auth?.steamId;
  if (steamId == null) return Stream.value(null);
  final db = ref.watch(databaseProvider);
  return db.settingsDao.watch(steamId);
});

/// Updates the completion threshold and immediately recalculates all statuses.
final setCompletionThresholdProvider =
    Provider<Future<void> Function(String threshold)>((ref) {
  return (String threshold) async {
    final steamId =
        ref.read(authProvider).asData?.value.steamId;
    if (steamId == null) return;
    final db = ref.read(databaseProvider);
    await db.settingsDao.write(
      AppSettingsCompanion(completionThreshold: Value(threshold)),
      steamId,
    );
    await db.gamesDao.recalculateAllStatuses(steamId);
  };
});

