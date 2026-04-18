import 'package:drift/drift.dart';

@TableIndex(name: 'idx_games_status', columns: {#status})
@TableIndex(name: 'idx_games_name', columns: {#name})
@TableIndex(name: 'idx_games_completed_at', columns: {#completedAt})
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get appId => integer().unique()(); // negative = manually added
  TextColumn get name => text()();
  IntColumn get playtimeMinutes => integer().withDefault(const Constant(0))();
  RealColumn get rushedHours => real().nullable()();
  RealColumn get casuallyHours => real().nullable()();
  RealColumn get completionistHours => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('backlog'))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get manualOverride =>
      boolean().withDefault(const Constant(false))();
}

class AppSettings extends Table {
  IntColumn get id => integer().check(id.equals(1))();
  TextColumn get completionThreshold =>
      text().withDefault(const Constant('casually'))();
  TextColumn get sortOrder => text().withDefault(const Constant('alpha'))();
  BoolColumn get showCompletedTab =>
      boolean().withDefault(const Constant(true))();
  TextColumn get theme => text().withDefault(const Constant('dark'))();

  @override
  Set<Column>? get primaryKey => {id};
}
