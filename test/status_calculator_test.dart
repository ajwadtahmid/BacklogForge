import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/services/database/app_database.dart';
import 'package:backlogforge/services/status_calculator.dart';
import 'package:backlogforge/models/game_status.dart';

Game _game({
  int playtimeMinutes = 0,
  double? essential,
  double? extended,
  double? completionist,
  String status = 'backlog',
  bool manualOverride = false,
  DateTime? completedAt,
}) =>
    Game(
      id: 1,
      steamId: 'test_user',
      appId: 1,
      name: 'Test Game',
      playtimeMinutes: playtimeMinutes,
      essentialHours: essential,
      extendedHours: extended,
      completionistHours: completionist,
      status: status,
      manualOverride: manualOverride,
      addedAt: DateTime(2024, 1, 1),
      completedAt: completedAt,
      lastPlayedAt: null,
      hltbImageUrl: null,
      hltbName: null,
      playStyle: null,
      hltbAttemptedAt: null,
    );

void main() {
  group('calculateStatus', () {
    group('no HLTB data', () {
      test('returns backlog when no hours set', () {
        expect(calculateStatus(_game(), CompletionThreshold.essential),
            GameStatus.backlog);
      });

      test('manual override respected when no HLTB data', () {
        final g = _game(status: 'playing', manualOverride: true);
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.playing);
      });
    });

    group('essential threshold', () {
      test('below essential → backlog', () {
        final g = _game(playtimeMinutes: 59, essential: 1.5);
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.backlog);
      });

      test('exactly at essential → completed', () {
        final g = _game(playtimeMinutes: 90, essential: 1.5); // 1.5h = 90min
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.completed);
      });

      test('above essential → completed', () {
        final g = _game(playtimeMinutes: 200, essential: 1.5);
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.completed);
      });
    });

    group('extended threshold', () {
      test('above extended → completed', () {
        final g = _game(playtimeMinutes: 600, extended: 9.0);
        expect(calculateStatus(g, CompletionThreshold.extended),
            GameStatus.completed);
      });

      test('falls back to essential if extended is null', () {
        // No extended hours; falls back to essential
        final g = _game(playtimeMinutes: 120, essential: 1.5, extended: null);
        expect(calculateStatus(g, CompletionThreshold.extended),
            GameStatus.completed);
      });

      test('below extended but above essential → backlog (extended preferred)', () {
        final g = _game(
            playtimeMinutes: 60, essential: 0.5, extended: 5.0);
        // 1h played / 5h extended → not done
        expect(calculateStatus(g, CompletionThreshold.extended),
            GameStatus.backlog);
      });
    });

    group('completionist threshold', () {
      test('falls back through extended then essential', () {
        // completionist=null, extended=null → falls back to essential=1.5h
        // 2h played >= 1.5h essential → completed
        final g = _game(playtimeMinutes: 120, essential: 1.5);
        expect(calculateStatus(g, CompletionThreshold.completionist),
            GameStatus.completed);
      });

      test('completionist wins when all three set', () {
        final g = _game(
          playtimeMinutes: 120,
          essential: 1.0,
          extended: 1.5,
          completionist: 3.0,
        );
        // 2h played < 3h completionist
        expect(calculateStatus(g, CompletionThreshold.completionist),
            GameStatus.backlog);
      });
    });

    group('manual override interaction', () {
      test('auto-complete takes priority over manualOverride', () {
        // Even with manualOverride=true, if playtime exceeds threshold → completed
        final g = _game(
          playtimeMinutes: 200,
          essential: 1.0,
          status: 'playing',
          manualOverride: true,
        );
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.completed);
      });

      test('manual playing preserved below threshold', () {
        final g = _game(
          playtimeMinutes: 30,
          essential: 5.0,
          status: 'playing',
          manualOverride: true,
        );
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.playing);
      });

      test('manual completed preserved below threshold', () {
        final g = _game(
          playtimeMinutes: 10,
          essential: 5.0,
          status: 'completed',
          manualOverride: true,
        );
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.completed);
      });

      test('no manualOverride → backlog regardless of stored status', () {
        final g = _game(
          playtimeMinutes: 10,
          essential: 5.0,
          status: 'playing',
          manualOverride: false,
        );
        expect(calculateStatus(g, CompletionThreshold.essential),
            GameStatus.backlog);
      });
    });
  });
}
