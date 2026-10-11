import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/games/article_swipe.dart';
import 'package:sprichst/domain/games/core_vocabulary.dart';
import 'package:sprichst/domain/games/dialogue_game.dart';
import 'package:sprichst/domain/games/game_models.dart';
import 'package:sprichst/domain/games/memory_match.dart';
import 'package:sprichst/domain/games/word_pool.dart';
import 'package:sprichst/domain/games/word_scramble.dart';
import 'package:sprichst/domain/games/wortle.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

final _course = Curriculum(loadCourse());
final _dialogues = loadCourseDialogues();
final _now = DateTime(2026, 10, 7, 9);
math.Random _rng() => math.Random(7);

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.preA1);

void main() {
  group('core vocabulary', () {
    test('has unique German words and a valid article on every noun', () {
      final words = coreNouns.map((w) => w.german.toLowerCase()).toList();
      expect(words.toSet().length, words.length);
      for (final w in coreNouns) {
        expect(articles, contains(w.article), reason: w.german);
      }
    });
  });

  group('WordPool', () {
    test('tops a new learner up from the core list', () {
      final nouns = WordPool.nouns(_learner(), _course);
      expect(nouns.length, greaterThanOrEqualTo(12));
    });

    test('puts words from started lessons ahead of filler', () {
      final lesson =
          _course.lessons.firstWhere((l) => l.vocabulary.any((w) => w.isNoun));
      final profile = const ProgressTracker().startLesson(_learner(), lesson);
      final nouns = WordPool.nouns(profile, _course, minimum: 1);
      final own = lesson.vocabulary.where((w) => w.isNoun).map((w) => w.id);
      expect(nouns.map((w) => w.id), containsAll(own));
    });
  });

  group('ComboMeter', () {
    test('multiplier rises every three hits and caps at 3x', () {
      final combo = ComboMeter();
      expect(combo.multiplier, 1);
      for (var i = 0; i < 3; i++) {
        combo.hit(10);
      }
      expect(combo.multiplier, 1.5);
      for (var i = 0; i < 30; i++) {
        combo.hit(10);
      }
      expect(combo.multiplier, ComboMeter.maxMultiplier);
      expect(combo.hit(10), 30);
    });

    test('a miss resets the streak but keeps the best', () {
      final combo = ComboMeter();
      for (var i = 0; i < 4; i++) {
        combo.hit(10);
      }
      combo.miss();
      expect(combo.combo, 0);
      expect(combo.best, 4);
      expect(combo.multiplier, 1);
    });
  });

  group('ArticleSwipeGame', () {
    test('scores right answers, ends after the last card', () {
      final game = ArticleSwipeGame(coreNouns, cards: 3);
      expect(game.answer(coreNouns[0].article!), isTrue);
      expect(
          game.answer('das' == coreNouns[1].article ? 'der' : 'das'), isFalse);
      expect(game.isOver, isFalse);
      expect(game.answer(coreNouns[2].article!), isTrue);
      expect(game.isOver, isTrue);
      expect(game.current, isNull);
      expect(game.correct, 2);
      expect(game.score, 20);
      final outcome = game.finish();
      expect(outcome.total, 3);
      expect(outcome.results.length, 3);
      expect(outcome.stars, 1);
    });

    test('the clock ends the round', () {
      final game = ArticleSwipeGame(coreNouns, seconds: 2);
      game.tick();
      expect(game.isOver, isFalse);
      game.tick();
      expect(game.isOver, isTrue);
      expect(game.answer('der'), isFalse);
    });

    test('only nouns are dealt', () {
      final game = ArticleSwipeGame.draw(coreNouns, _rng());
      expect(game.total, 20);
    });
  });

  group('MemoryMatchGame', () {
    test('matching all pairs finishes the game', () {
      final game = MemoryMatchGame(coreNouns, _rng());
      expect(game.tiles.length, 12);
      for (var i = 0; i < game.tiles.length; i++) {
        if (game.isMatched(i)) continue;
        final j = game.tiles
            .indexWhere((t) => t.pairId == game.tiles[i].pairId, i + 1);
        expect(game.flip(i), isNull);
        expect(game.flip(j), isTrue);
      }
      expect(game.isOver, isTrue);
      final outcome = game.finish();
      expect(outcome.stars, 3);
      expect(outcome.correct, 6);
    });

    test('a mismatch stays up until hidden and blocks other flips', () {
      final game = MemoryMatchGame(coreNouns, _rng());
      final a = 0;
      final b = game.tiles.indexWhere((t) => t.pairId != game.tiles[a].pairId);
      game.flip(a);
      expect(game.flip(b), isFalse);
      expect(game.isResolving, isTrue);
      expect(game.flip(5), isNull);
      expect(game.faceUp, [a, b]);
      game.hideMismatch();
      expect(game.faceUp, isEmpty);
      expect(game.moves, 1);
    });

    test('flipping a shown tile does nothing', () {
      final game = MemoryMatchGame(coreNouns, _rng());
      game.flip(0);
      expect(game.flip(0), isNull);
      expect(game.faceUp, [0]);
    });
  });

  group('WordScrambleGame', () {
    test('a scramble always differs from the word', () {
      for (var seed = 0; seed < 40; seed++) {
        final letters = WordScrambleGame.scramble('Tisch', math.Random(seed));
        expect(letters.join(), isNot('Tisch'));
        expect([...letters]..sort(), 'Tisch'.split('')..sort());
      }
    });

    test('guesses forgive case and umlaut spelling; wrong ones keep the round',
        () {
      final game = WordScrambleGame(
          [coreNouns.firstWhere((w) => w.german == 'Käse')], _rng(),
          rounds: 1);
      expect(game.guess('KAESE'), isTrue); // ae for ä, any case
      expect(game.isOver, isTrue);
    });

    test('hints reveal letters and cost points', () {
      final word = coreNouns.firstWhere((w) => w.german == 'Tisch');
      final plain = WordScrambleGame([word], _rng(), rounds: 1)..guess('Tisch');
      final hinted = WordScrambleGame([word], _rng(), rounds: 1)
        ..hint()
        ..hint();
      expect(hinted.hintText, 'Ti');
      hinted.guess('Tisch');
      expect(hinted.score, lessThan(plain.score));
      expect(hinted.score, greaterThan(0));
    });

    test('a wrong guess does not advance; skip does', () {
      final game = WordScrambleGame(coreNouns, _rng(), rounds: 2);
      expect(game.guess('xxxx'), isFalse);
      expect(game.index, 0);
      game.skip();
      expect(game.index, 1);
      expect(game.finish().correct, 0);
    });
  });

  group('Wortle', () {
    test('marks exact, misplaced and absent letters', () {
      expect(WortleGame.evaluate('TISCH', 'TISCH'),
          everyElement(LetterMark.correct));
      expect(WortleGame.evaluate('STUHL', 'TISCH'), [
        LetterMark.present, // S is in TISCH
        LetterMark.present, // T
        LetterMark.absent, // U
        LetterMark.present, // H
        LetterMark.absent, // L
      ]);
    });

    test('repeated letters are only marked as often as they occur', () {
      // The answer has one E and one A.
      final marks = WortleGame.evaluate('EEEAA', 'AEBCD');
      expect(marks, [
        LetterMark.absent,
        LetterMark.correct,
        LetterMark.absent,
        LetterMark.present,
        LetterMark.absent,
      ]);
    });

    test('wins, loses, and rejects bad guesses', () {
      final game = WortleGame('TISCH');
      expect(game.submit('abc'), isNull);
      expect(game.submit('12345'), isNull);
      expect(game.submit('tisch'), isNotNull);
      expect(game.isWon, isTrue);
      expect(game.submit('LAMPE'), isNull); // over

      final lose = WortleGame('TISCH');
      for (var i = 0; i < WortleGame.maxGuesses; i++) {
        lose.submit('LAMPE');
      }
      expect(lose.isLost, isTrue);
      expect(lose.finish().correct, 0);
    });

    test('umlauts count as single letters', () {
      expect(WortleGame.isValidGuess('GLÜCK'), isTrue);
      final game = WortleGame('GLÜCK');
      expect(game.submit('glück'), isNotNull);
      expect(game.isWon, isTrue);
    });

    test('keyboard keeps the best mark per letter', () {
      final game = WortleGame('TISCH')
        ..submit('STUHL')
        ..submit('TISCH');
      expect(game.keyboard['T'], LetterMark.correct);
      expect(game.keyboard['U'], LetterMark.absent);
    });

    test('the daily word is stable and always five letters', () {
      final a = WortleGame.pickAnswer(const [], 20261007);
      expect(a, WortleGame.pickAnswer(const [], 20261007));
      for (var seed = 0; seed < 100; seed++) {
        expect(WortleGame.pickAnswer(const [], seed).length, 5);
      }
    });
  });

  group('DialogueGame', () {
    test('walks a dialogue, scoring each reply', () {
      final dialogue = _dialogues.first;
      final game = DialogueGame(dialogue, _rng());
      var replies = 0;
      while (true) {
        game.advance();
        final turn = game.pending;
        if (turn == null) break;
        expect(game.options.toSet(), turn.options.toSet());
        game.reply(turn.answer!);
        replies++;
      }
      expect(game.isOver, isTrue);
      expect(replies, dialogue.gapCount);
      final outcome = game.finish();
      expect(outcome.stars, 3);
      expect(outcome.correct, dialogue.gapCount);
    });

    test('wrong replies score nothing', () {
      final dialogue = _dialogues.first;
      final game = DialogueGame(dialogue, _rng())..advance();
      final turn = game.pending!;
      final wrong = turn.options.firstWhere((o) => o != turn.answer);
      expect(game.reply(wrong), isFalse);
      expect(game.score, 0);
    });

    test('dialoguesFor keeps to the learner level and prefers topics', () {
      final all = _dialogues;
      final picked = dialoguesFor(all, CefrLevel.preA1, {});
      for (final d in picked) {
        expect(d.level.index, lessThanOrEqualTo(CefrLevel.preA1.index));
      }
    });
  });

  group('ProgressTracker.completeGame', () {
    test('feeds skills, XP, records and the streak', () {
      final game = ArticleSwipeGame(coreNouns, cards: 4);
      for (final noun in coreNouns.take(4)) {
        game.answer(noun.article!);
      }
      final outcome = game.finish();
      final update =
          const ProgressTracker().completeGame(_learner(), outcome, now: _now);
      expect(update.xpEarned, outcome.xp);
      expect(update.profile.xp, outcome.xp);
      expect(update.profile.skillStats['definite_articles']!.attempts, 4);
      expect(update.profile.gamification.gamesPlayed, 1);
      expect(
          update.profile.gamification.gameBest['articleSwipe'], outcome.score);
      expect(update.profile.streak, 1);
      expect(update.profile.reviewItems, isEmpty);
    });

    test('best score only goes up', () {
      const tracker = ProgressTracker();
      GameOutcome outcome(int score) => GameOutcome(
          game: GameId.wortle,
          score: score,
          correct: 1,
          total: 1,
          stars: 3,
          bestCombo: 0,
          results: const []);
      var profile =
          tracker.completeGame(_learner(), outcome(80), now: _now).profile;
      profile = tracker.completeGame(profile, outcome(40), now: _now).profile;
      expect(profile.gamification.gameBest['wortle'], 80);
      expect(profile.gamification.gamesPlayed, 2);
    });
  });
}
