import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

/// Data access object for managing application settings.
/// Provides read/write helpers for the singleton AppSettings row (id = 1).
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Reads the current app settings.
  /// The singleton row is guaranteed to exist from database initialization.
  Future<AppSetting> read() {
    return (select(appSettings)..where((s) => s.id.equals(1)))
      .getSingle();
  }

  /// Updates app settings with the provided changes.
  Future<void> write(AppSettingsCompanion changes) async {
    await (update(appSettings)..where((s) => s.id.equals(1)))
      .write(changes);
  }

  /// Watches for changes to app settings; emits the current row whenever it changes.
  Stream<AppSetting> watch() {
    return (select(appSettings)..where((s) => s.id.equals(1)))
      .watchSingle();
  }
}
