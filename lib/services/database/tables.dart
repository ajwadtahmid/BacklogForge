import 'package:drift/drift.dart';

@TableIndex(name: 'idx_games_status', columns: {#status})
@TableIndex(name: 'idx_games_name', columns: {#name})
@TableIndex(name: 'idx_games_completed_at', columns: {#completedAt})
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get steamId => text()();
  // Negative appId = manually added game. Unique per user, not globally.
  IntColumn get appId => integer()();
  TextColumn get name => text()();
  IntColumn get playtimeMinutes => integer().withDefault(const Constant(0))();
  RealColumn get essentialHours => real().nullable()();
  RealColumn get extendedHours => real().nullable()();
  RealColumn get completionistHours => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('backlog'))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  TextColumn get hltbImageUrl => text().nullable()();
  TextColumn get hltbName => text().nullable()();
  // 'essential' | 'extended' | 'completionist' | null (defaults to essential).
  TextColumn get playStyle => text().nullable()();
  BoolColumn get manualOverride =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {steamId, appId},
      ];
}



class AppSettings extends Table {
  TextColumn get steamId => text()();
  TextColumn get completionThreshold =>
      text().withDefault(const Constant('essential'))();
  TextColumn get sortOrder => text().withDefault(const Constant('alpha'))();
  BoolColumn get showCompletedTab =>
      boolean().withDefault(const Constant(true))();
  TextColumn get theme => text().withDefault(const Constant('dark'))();
  RealColumn get dailyBudgetHours =>
      real().withDefault(const Constant(1.0))();

  @override
  Set<Column>? get primaryKey => {steamId};
}
