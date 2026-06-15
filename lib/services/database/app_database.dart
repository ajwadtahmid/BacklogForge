import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables.dart';
import 'games_dao.dart';
import 'settings_dao.dart';
import 'stats_dao.dart';

part 'app_database.g.dart';

// Schema version history:
//   1 — initial schema
//   2 — replaced 'auth' table with AppSettings
//   3 — renamed rushed_hours → essential_hours, casually_hours → extended_hours
//   4 — full table rebuild (column additions required drop/recreate)
//   5 — added last_played_at to Games
//   6 — added hltb_image_url to Games
//   7 — added play_style to Games
//   8 — added daily_budget_hours to AppSettings
//   9 — added hltb_name to Games
//  10 — added hltb_attempted_at to Games
//  11 — added notes and rating to Games
//  12 — daily_budget_hours default changed from 1.0 to 0.0 (0 = no budget set)
const int schemaVersionNumber = 12;

@DriftDatabase(tables: [Games, AppSettings], daos: [GamesDao, SettingsDao, StatsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// In-memory database for unit tests. Pass [NativeDatabase.memory()].
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => schemaVersionNumber;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, fromVersion, toVersion) async {
      if (fromVersion < 2) {
        await m.deleteTable('auth');
        await m.createTable(appSettings);
      }
      if (fromVersion < 3) {
        await customStatement(
          'ALTER TABLE games RENAME COLUMN rushed_hours TO essential_hours',
        );
        await customStatement(
          'ALTER TABLE games RENAME COLUMN casually_hours TO extended_hours',
        );
      }
      if (fromVersion < 4) {
        await m.drop(games);
        await m.drop(appSettings);
        await m.createAll();
      }
      if (fromVersion < 5) {
        await m.addColumn(games, games.lastPlayedAt);
      }
      if (fromVersion < 6) {
        await m.addColumn(games, games.hltbImageUrl);
      }
      if (fromVersion < 7) {
        await m.addColumn(games, games.playStyle);
      }
      if (fromVersion < 8) {
        await m.addColumn(appSettings, appSettings.dailyBudgetHours);
      }
      if (fromVersion < 9) {
        await m.addColumn(games, games.hltbName);
      }
      if (fromVersion < 10) {
        await m.addColumn(games, games.hltbAttemptedAt);
      }
      if (fromVersion < 11) {
        await m.addColumn(games, games.notes);
        await m.addColumn(games, games.rating);
      }
      // v12: no structural changes — daily_budget_hours column default changed
      // in Drift layer only. Existing rows keep their stored value.
    },
  );

  static QueryExecutor _open() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return LazyDatabase(() async {
        final dir = await getApplicationSupportDirectory();
        final dbFile = File(p.join(dir.path, 'backlogforge.db'));
        return NativeDatabase(dbFile);
      });
    }
    return driftDatabase(name: 'backlogforge');
  }
}
