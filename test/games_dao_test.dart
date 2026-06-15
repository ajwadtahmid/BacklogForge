import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/services/database/app_database.dart';
import 'package:backlogforge/services/database/games_dao.dart';
import 'package:backlogforge/models/game_status.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Inserts a minimal game row for testing. [appId] must be unique per [steamId].
Future<void> _insertGame(
  AppDatabase db, {
  required int appId,
  required String steamId,
  String name = 'Test Game',
  int playtimeMinutes = 0,
  double? essentialHours,
  double? extendedHours,
  double? completionistHours,
  String status = 'backlog',
  bool manualOverride = false,
  DateTime? completedAt,
  DateTime? lastPlayedAt,
  String? playStyle,
}) async {
  await db.into(db.games).insert(GamesCompanion.insert(
    steamId: steamId,
    appId: appId,
    name: name,
    playtimeMinutes: Value(playtimeMinutes),
    essentialHours: Value(essentialHours),
    extendedHours: Value(extendedHours),
    completionistHours: Value(completionistHours),
    status: Value(status),
    manualOverride: Value(manualOverride),
    addedAt: DateTime(2024, 1, 1),
    completedAt: Value(completedAt),
    lastPlayedAt: Value(lastPlayedAt),
    playStyle: Value(playStyle),
  ));
}

void main() {
  group('recalculateAllStatuses', () {
    late AppDatabase db;

    setUp(() => db = _openDb());
    tearDown(() => db.close());

    test('auto-completes a game whose playtime exceeds essential threshold', () async {
      await _insertGame(db,
          appId: 1, steamId: 's1', playtimeMinutes: 600, essentialHours: 9.0);
      await db.gamesDao.recalculateAllStatuses('s1');
      final game = await (db.select(db.games)
            ..where((g) => g.steamId.equals('s1')))
          .getSingle();
      expect(game.status, GameStatus.completed.name);
      expect(game.completedAt, isNotNull);
    });

    test('stamps completedAt only once (idempotent on subsequent calls)', () async {
      await _insertGame(db,
          appId: 1, steamId: 's1', playtimeMinutes: 600, essentialHours: 9.0);
      await db.gamesDao.recalculateAllStatuses('s1');
      final first = await (db.select(db.games)
            ..where((g) => g.steamId.equals('s1')))
          .getSingle();
      final firstStamp = first.completedAt;

      // Second pass must not overwrite completedAt.
      await db.gamesDao.recalculateAllStatuses('s1');
      final second = await (db.select(db.games)
            ..where((g) => g.steamId.equals('s1')))
          .getSingle();
      expect(second.completedAt, firstStamp);
    });

    test('leaves backlog game alone when below threshold', () async {
      await _insertGame(db,
          appId: 1, steamId: 's1', playtimeMinutes: 30, essentialHours: 10.0);
      await db.gamesDao.recalculateAllStatuses('s1');
      final game = await (db.select(db.games)
            ..where((g) => g.steamId.equals('s1')))
          .getSingle();
      expect(game.status, 'backlog');
    });

    test('does not override replaying completed game', () async {
      // manualOverride=true, status=playing, completedAt set → should stay as-is
      await _insertGame(db,
          appId: 1,
          steamId: 's1',
          playtimeMinutes: 30,
          essentialHours: 10.0,
          status: 'playing',
          manualOverride: true,
          completedAt: DateTime(2024, 1, 1));
      await db.gamesDao.recalculateAllStatuses('s1');
      final game = await (db.select(db.games)
            ..where((g) => g.steamId.equals('s1')))
          .getSingle();
      expect(game.status, 'playing');
    });

    test('returns count of newly auto-completed games', () async {
      await _insertGame(db,
          appId: 1, steamId: 's1', playtimeMinutes: 600, essentialHours: 9.0);
      await _insertGame(db,
          appId: 2, steamId: 's1', name: 'Short Game', playtimeMinutes: 120,
          essentialHours: 20.0);
      final count = await db.gamesDao.recalculateAllStatuses('s1');
      expect(count, 1); // only appId=1 crosses the threshold
    });

    test('handles empty library without error', () async {
      final count = await db.gamesDao.recalculateAllStatuses('nobody');
      expect(count, 0);
    });
  });

  group('watchBacklogSorted / watchCompletedSorted', () {
    late AppDatabase db;

    setUp(() => db = _openDb());
    tearDown(() => db.close());

    test('backlog excludes completed-but-replaying games', () async {
      // Replaying: status=playing, completedAt set → belongs in completed tab
      await _insertGame(db,
          appId: 1, steamId: 's1', status: 'playing',
          completedAt: DateTime(2024, 1, 1));
      await _insertGame(db,
          appId: 2, steamId: 's1', name: 'Backlog Game', status: 'backlog');

      final backlog = await db.gamesDao
          .watchBacklogSorted(SortMode.alphabetical, 's1')
          .first;
      expect(backlog.length, 1);
      expect(backlog.first.name, 'Backlog Game');
    });

    test('completed includes replaying games', () async {
      await _insertGame(db,
          appId: 1, steamId: 's1', status: 'playing',
          completedAt: DateTime(2024, 1, 1));
      await _insertGame(db,
          appId: 2, steamId: 's1', name: 'Done', status: 'completed',
          completedAt: DateTime(2024, 2, 1));

      final completed = await db.gamesDao
          .watchCompletedSorted(SortMode.alphabetical, 's1')
          .first;
      expect(completed.length, 2);
    });

    test('alphabetical sort orders by name ascending', () async {
      await _insertGame(db, appId: 1, steamId: 's1', name: 'Zelda');
      await _insertGame(db, appId: 2, steamId: 's1', name: 'Elden Ring');
      await _insertGame(db, appId: 3, steamId: 's1', name: 'Hollow Knight');

      final backlog = await db.gamesDao
          .watchBacklogSorted(SortMode.alphabetical, 's1')
          .first;
      expect(backlog.map((g) => g.name).toList(),
          ['Elden Ring', 'Hollow Knight', 'Zelda']);
    });

    test('neglected sort filters to zero-playtime games only', () async {
      await _insertGame(db, appId: 1, steamId: 's1', name: 'Unplayed',
          playtimeMinutes: 0);
      await _insertGame(db, appId: 2, steamId: 's1', name: 'Played',
          playtimeMinutes: 60);

      final backlog = await db.gamesDao
          .watchBacklogSorted(SortMode.neglected, 's1')
          .first;
      expect(backlog.length, 1);
      expect(backlog.first.name, 'Unplayed');
    });

    test('playing games pin to top of backlog regardless of sort mode', () async {
      await _insertGame(db, appId: 1, steamId: 's1', name: 'Alpha');
      await _insertGame(db, appId: 2, steamId: 's1', name: 'Playing Now',
          status: 'playing');

      final backlog = await db.gamesDao
          .watchBacklogSorted(SortMode.alphabetical, 's1')
          .first;
      expect(backlog.first.name, 'Playing Now');
    });
  });

  group('addManualGame / _nextManualAppId', () {
    late AppDatabase db;

    setUp(() => db = _openDb());
    tearDown(() => db.close());

    test('first manual game gets appId -1', () async {
      await db.gamesDao.addManualGame('My Game', null, 's1');
      final games = await db.gamesDao.getAllGames('s1');
      expect(games.first.appId, -1);
    });

    test('second manual game gets appId -2, no collision', () async {
      await db.gamesDao.addManualGame('Game A', null, 's1');
      await db.gamesDao.addManualGame('Game B', null, 's1');
      final games = await db.gamesDao.getAllGames('s1');
      final ids = games.map((g) => g.appId).toSet();
      expect(ids, {-1, -2});
    });

    test('manual IDs do not collide with Steam IDs', () async {
      // Insert a Steam game with a positive appId first.
      await _insertGame(db, appId: 12345, steamId: 's1', name: 'Steam Game');
      await db.gamesDao.addManualGame('Manual', null, 's1');
      final games = await db.gamesDao.getAllGames('s1');
      final manual = games.where((g) => g.appId < 0).toList();
      expect(manual.length, 1);
      expect(manual.first.appId, -1);
    });
  });
}
