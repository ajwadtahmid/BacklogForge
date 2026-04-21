import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

part 'stats_dao.g.dart';

@DriftAccessor(tables: [Games])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.db);

  /// Number of games with status backlog or playing.
  Future<int> backlogCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.status.isIn(['backlog', 'playing']) &
            games.steamId.equals(steamId),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Sum of extended hours across all backlog/playing games.
  Future<double> hoursRemaining(String steamId) async {
    final total = games.extendedHours.sum();
    final query = selectOnly(games)
      ..addColumns([total])
      ..where(
        games.status.isIn(['backlog', 'playing']) &
            games.steamId.equals(steamId),
      );
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// Number of games completed since the start of the current calendar month.
  Future<int> completedThisMonth(String steamId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.status.equals('completed') &
            games.steamId.equals(steamId) &
            games.completedAt.isBiggerOrEqualValue(startOfMonth),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Total number of completed games.
  Future<int> completedCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.status.equals('completed') & games.steamId.equals(steamId),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Number of games currently in the playing state.
  Future<int> playingCount(String steamId) async {
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(games.status.equals('playing') & games.steamId.equals(steamId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Number of games added to the library since the start of the current calendar month.
  Future<int> addedThisMonth(String steamId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final count = games.id.count();
    final query = selectOnly(games)
      ..addColumns([count])
      ..where(
        games.steamId.equals(steamId) &
            games.addedAt.isBiggerOrEqualValue(startOfMonth),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
