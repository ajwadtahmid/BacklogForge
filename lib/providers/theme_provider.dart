import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Streams the persisted theme from the database, defaulting to dark when
/// the user is not signed in. Consumed by [main.dart] to drive [MaterialApp.themeMode].
final themeProvider = StreamProvider<ThemeMode>((ref) async* {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) {
    yield ThemeMode.dark;
    return;
  }
  yield* ref.watch(databaseProvider).settingsDao.watch(steamId).map(
        (settings) =>
            settings.theme == 'light' ? ThemeMode.light : ThemeMode.dark,
      );
});

/// Write-only notifier: persists a theme change to the database.
/// The UI reacts via [themeProvider]'s DB stream — this notifier's own
/// state is intentionally unused.
final themeModeNotifierProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  Future<void> setTheme(ThemeMode mode) async {
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId;
    if (steamId == null) return;
    final db = ref.read(databaseProvider);
    final themeStr = mode == ThemeMode.light ? 'light' : 'dark';
    await db.settingsDao.write(
      AppSettingsCompanion(theme: Value(themeStr)),
      steamId,
    );
    // No state update needed: themeProvider's DB stream propagates the change.
  }
}
