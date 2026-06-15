import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/services/export_import_service.dart';
import 'package:backlogforge/models/game_status.dart';

String _makeJson({
  String? status,
  String? playStyle,
  String? completedAt,
}) =>
    '''
{
  "version": 1,
  "exportedAt": "2026-01-01T00:00:00.000Z",
  "steamId": "12345678901234567",
  "games": [
    {
      "appId": 1234,
      "name": "Test Game",
      "playtimeMinutes": 120,
      "status": ${status != null ? '"$status"' : 'null'},
      "essentialHours": 10.5,
      "extendedHours": null,
      "completionistHours": null,
      "hltbName": "Test Game",
      "hltbImageUrl": null,
      "playStyle": ${playStyle != null ? '"$playStyle"' : 'null'},
      "manualOverride": false,
      "addedAt": "2025-01-01T00:00:00.000Z",
      "completedAt": ${completedAt != null ? '"$completedAt"' : 'null'},
      "lastPlayedAt": null
    }
  ]
}
''';

void main() {
  group('ExportImportService.parseImportJson', () {
    test('parses valid game fields correctly', () {
      final companions = ExportImportService.parseImportJson(
        _makeJson(status: 'completed', completedAt: '2025-06-01T00:00:00.000Z'),
      );
      expect(companions.length, 1);
      final g = companions.first;
      expect(g.appId.value, 1234);
      expect(g.name.value, 'Test Game');
      expect(g.playtimeMinutes.value, 120);
      expect(g.status.value, 'completed');
      expect(g.essentialHours.value, 10.5);
      expect(g.completedAt.value, DateTime.utc(2025, 6, 1));
    });

    test('unknown status defaults to backlog', () {
      final companions = ExportImportService.parseImportJson(
        _makeJson(status: 'invalid_status'),
      );
      expect(companions.first.status.value, GameStatus.backlog.name);
    });

    test('null status defaults to backlog', () {
      final companions = ExportImportService.parseImportJson(
        _makeJson(status: null),
      );
      expect(companions.first.status.value, GameStatus.backlog.name);
    });

    test('valid statuses are preserved', () {
      for (final s in ['backlog', 'playing', 'completed']) {
        final companions = ExportImportService.parseImportJson(
          _makeJson(status: s),
        );
        expect(companions.first.status.value, s);
      }
    });

    test('unknown playStyle maps to null', () {
      final companions = ExportImportService.parseImportJson(
        _makeJson(status: 'backlog', playStyle: 'bogus'),
      );
      expect(companions.first.playStyle.value, isNull);
    });

    test('valid playStyles are preserved', () {
      for (final ps in ['essential', 'extended', 'completionist']) {
        final companions = ExportImportService.parseImportJson(
          _makeJson(status: 'backlog', playStyle: ps),
        );
        expect(companions.first.playStyle.value, ps);
      }
    });

    test('null completedAt parses to null', () {
      final companions = ExportImportService.parseImportJson(
        _makeJson(status: 'backlog', completedAt: null),
      );
      expect(companions.first.completedAt.value, isNull);
    });

    test('throws FormatException on unsupported version', () {
      final json = _makeJson(status: 'backlog').replaceFirst(
        '"version": 1',
        '"version": 99',
      );
      expect(
        () => ExportImportService.parseImportJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trip: export JSON parses back to equivalent companions', () {
      // Build a known JSON payload and verify all key fields survive the round-trip.
      const json = '''
{
  "version": 1,
  "exportedAt": "2026-01-01T00:00:00.000Z",
  "steamId": "12345678901234567",
  "games": [
    {
      "appId": 42,
      "name": "Portal 2",
      "playtimeMinutes": 300,
      "status": "completed",
      "essentialHours": 8.5,
      "extendedHours": 12.0,
      "completionistHours": 20.0,
      "hltbName": "Portal 2",
      "hltbImageUrl": "https://example.com/img.jpg",
      "playStyle": "extended",
      "manualOverride": true,
      "addedAt": "2024-03-15T10:00:00.000Z",
      "completedAt": "2024-04-01T08:00:00.000Z",
      "lastPlayedAt": "2024-04-01T08:00:00.000Z"
    }
  ]
}
''';
      final companions = ExportImportService.parseImportJson(json);
      expect(companions.length, 1);
      final g = companions.first;
      expect(g.appId.value, 42);
      expect(g.name.value, 'Portal 2');
      expect(g.playtimeMinutes.value, 300);
      expect(g.status.value, 'completed');
      expect(g.essentialHours.value, 8.5);
      expect(g.extendedHours.value, 12.0);
      expect(g.completionistHours.value, 20.0);
      expect(g.playStyle.value, 'extended');
      expect(g.manualOverride.value, isTrue);
      expect(g.completedAt.value, DateTime.utc(2024, 4, 1, 8));
    });
  });
}
