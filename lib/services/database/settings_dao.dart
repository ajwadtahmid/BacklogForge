import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<AppSetting> read(String steamId) =>
      (select(appSettings)..where((s) => s.steamId.equals(steamId))).getSingle();

  Future<void> write(AppSettingsCompanion changes, String steamId) =>
      (update(appSettings)..where((s) => s.steamId.equals(steamId)))
          .write(changes);

  Stream<AppSetting> watch(String steamId) =>
      (select(appSettings)..where((s) => s.steamId.equals(steamId)))
          .watchSingle();

  /// Inserts a default settings row for this user if one doesn't exist yet.
  Future<void> seedIfAbsent(String steamId) => into(appSettings).insert(
        AppSettingsCompanion.insert(steamId: steamId),
        mode: InsertMode.insertOrIgnore,
      );
}
