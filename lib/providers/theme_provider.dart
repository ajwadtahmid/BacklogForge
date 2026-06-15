import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

const _kThemeKey = 'theme';
const _kNavPositionKey = 'nav_position';

enum NavigationPosition { top, left, right }

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
      return ThemeMode.system;
    }
    return _decode(raw);
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
      state = _decode(settings.theme);
    } catch (_) {
      // DB not ready yet — harmless; prefs will be populated on next setTheme.
    }
  }

  static ThemeMode _decode(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class NavigationPositionNotifier extends Notifier<NavigationPosition> {
  @override
  NavigationPosition build() {
    final raw = ref.read(sharedPrefsProvider).getString(_kNavPositionKey);
    return switch (raw) {
      'left' => NavigationPosition.left,
      'right' => NavigationPosition.right,
      _ => NavigationPosition.top,
    };
  }

  Future<void> setPosition(NavigationPosition position) async {
    state = position;
    final str = switch (position) {
      NavigationPosition.top => 'top',
      NavigationPosition.left => 'left',
      NavigationPosition.right => 'right',
    };
    await ref.read(sharedPrefsProvider).setString(_kNavPositionKey, str);
  }
}

final navigationPositionProvider =
    NotifierProvider<NavigationPositionNotifier, NavigationPosition>(
        NavigationPositionNotifier.new);
