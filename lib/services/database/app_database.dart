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

const int schemaVersionNumber = 7;

@DriftDatabase(tables: [Games, AppSettings], daos: [GamesDao, SettingsDao, StatsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

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
