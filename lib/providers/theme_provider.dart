import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

const _kThemeKey = 'theme';

/// Injected via [ProviderScope.overrides] in main() before runApp, so the
/// value is always available synchronously to [themeProvider].
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences not injected'),
);

/// Manages the app theme. Reads from [SharedPreferences] synchronously on
/// startup — no auth dependency, no flicker. Mirrors every change to the DB
/// so the preference survives a prefs wipe (e.g. app reinstall with backup).
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.read(sharedPrefsProvider).getString(_kThemeKey);
    if (raw == null) {
      // No cached value yet — sync from DB after auth resolves.
      Future.microtask(_syncFromDb);
    }
    return raw == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode; // immediate reactive update — no flicker
    final themeStr = _encode(mode);
    await ref.read(sharedPrefsProvider).setString(_kThemeKey, themeStr);
    // Mirror to DB for cross-device / backup persistence.
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId;
    if (steamId != null) {
      await ref.read(databaseProvider).settingsDao.write(
            AppSettingsCompanion(theme: Value(themeStr)),
            steamId,
          );
    }
  }

  /// On first launch (or after prefs wipe) pull the theme from the DB once
  /// auth has resolved, then update state and prefs to match.
  Future<void> _syncFromDb() async {
    try {
      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId;
      if (steamId == null) return;
      final settings = await ref.read(databaseProvider).settingsDao.read(steamId);
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString(_kThemeKey, settings.theme);
      state = settings.theme == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      // DB not ready yet — harmless; prefs will be populated on next setTheme.
    }
  }

  static String _encode(ThemeMode mode) =>
      mode == ThemeMode.light ? 'light' : 'dark';
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
