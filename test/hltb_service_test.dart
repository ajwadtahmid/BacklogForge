import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/services/hltb_service.dart';

void main() {
  group('HltbService.normalise', () {
    test('lowercases the result', () {
      expect(HltbService.normalise('Elden Ring'), 'elden ring');
    });

    test('strips trademark symbol ™', () {
      expect(HltbService.normalise('Game™'), 'game');
    });

    test('strips registered symbol ®', () {
      // ® is removed; whitespace collapser then reduces any double-space to single.
      expect(HltbService.normalise('Game® 2'), 'game 2');
    });

    test('strips copyright symbol ©', () {
      expect(HltbService.normalise('©Game'), 'game');
    });

    test('strips service mark ℠', () {
      expect(HltbService.normalise('Game℠'), 'game');
    });

    test('strips (r) and (tm) case-insensitively', () {
      // (R)/(TM) is removed, then whitespace collapsed.
      expect(HltbService.normalise('Game(R) Edition'), 'game edition');
      expect(HltbService.normalise('Game(TM) Edition'), 'game edition');
    });

    test('replaces special punctuation with space, then collapses', () {
      // ':' → space, existing space after ':' → double-space, then collapsed.
      final result = HltbService.normalise('The Witcher: Wild Hunt');
      expect(result, 'the witcher wild hunt');
    });

    test('collapses multiple whitespace', () {
      final result = HltbService.normalise('Game   Name');
      expect(result, 'game name');
    });

    test('trims leading and trailing whitespace', () {
      final result = HltbService.normalise('  Game Name  ');
      expect(result, 'game name');
    });

    test('unchanged name returns lowercase', () {
      // Already clean — normalise just lowercases it.
      final input = 'stardew valley';
      expect(HltbService.normalise(input), input);
    });

    test('real-world Steam name with trademark', () {
      final result = HltbService.normalise('STAR WARS™ Jedi: Fallen Order™');
      expect(result.contains('™'), isFalse);
      expect(result.contains(':'), isFalse);
      expect(result, contains('star wars'));
      expect(result, contains('jedi'));
      expect(result, contains('fallen order'));
    });
  });
}
