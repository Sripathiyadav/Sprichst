import 'dart:math' as math;

import 'game_models.dart';
import '../models/learning_models.dart';

enum LetterMark { absent, present, correct }

/// Wortle: guess the five-letter German word in six tries. Any five letters are
/// accepted as a guess (there is no full dictionary on the device); the colours
/// do the teaching.
class WortleGame {
  WortleGame(this.answer) : assert(answer.length == wordLength);

  static const wordLength = 5;
  static const maxGuesses = 6;

  /// The answer in capitals, with umlauts (Ä, Ö, Ü) kept as single letters.
  final String answer;
  final List<String> guesses = [];
  final List<List<LetterMark>> marks = [];

  bool get isWon => guesses.isNotEmpty && guesses.last == answer;
  bool get isLost => !isWon && guesses.length >= maxGuesses;
  bool get isOver => isWon || isLost;

  /// Normalises typed input: capitals, `ß` kept, nothing else.
  static String clean(String input) => input.toUpperCase().trim();

  static bool isValidGuess(String guess) =>
      guess.length == wordLength && RegExp(r'^[A-ZÄÖÜß]+$').hasMatch(guess);

  /// Submits [input]; returns its marks, or null when it is not a valid guess
  /// or the game is over.
  List<LetterMark>? submit(String input) {
    final guess = clean(input);
    if (isOver || !isValidGuess(guess)) return null;
    final result = evaluate(guess, answer);
    guesses.add(guess);
    marks.add(result);
    return result;
  }

  /// Standard two-pass scoring, so repeated letters are marked correctly: exact
  /// matches first, then each remaining answer letter can mark one misplaced
  /// guess letter.
  static List<LetterMark> evaluate(String guess, String answer) {
    final result = List.filled(wordLength, LetterMark.absent);
    final remaining = <String, int>{};
    for (var i = 0; i < wordLength; i++) {
      if (guess[i] == answer[i]) {
        result[i] = LetterMark.correct;
      } else {
        remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
      }
    }
    for (var i = 0; i < wordLength; i++) {
      if (result[i] == LetterMark.correct) continue;
      final left = remaining[guess[i]] ?? 0;
      if (left > 0) {
        result[i] = LetterMark.present;
        remaining[guess[i]] = left - 1;
      }
    }
    return result;
  }

  /// The best mark each letter has earned so far, for colouring the keyboard.
  Map<String, LetterMark> get keyboard {
    final best = <String, LetterMark>{};
    for (var g = 0; g < guesses.length; g++) {
      for (var i = 0; i < wordLength; i++) {
        final letter = guesses[g][i];
        final mark = marks[g][i];
        final previous = best[letter];
        if (previous == null || mark.index > previous.index) {
          best[letter] = mark;
        }
      }
    }
    return best;
  }

  GameOutcome finish() {
    final used = guesses.length;
    return GameOutcome(
      game: GameId.wortle,
      score: isWon ? 100 - (used - 1) * 15 : 0,
      correct: isWon ? 1 : 0,
      total: 1,
      stars: !isWon
          ? 0
          : used <= 3
              ? 3
              : used <= 5
                  ? 2
                  : 1,
      bestCombo: 0,
      results: [
        gameResult(
          gameQuestion(
            id: 'wortle/$answer',
            prompt: 'Five-letter word',
            answer: answer,
            skills: const ['vocabulary'],
            area: SkillArea.vocabulary,
            kind: ExerciseKind.fillBlank,
          ),
          guesses.isEmpty ? '' : guesses.last,
          isWon,
        ),
      ],
    );
  }

  /// Chooses the day's word: the learner's own five-letter words first, then
  /// the built-in list. [seed] is usually the date, so the word is the same
  /// all day, like the original.
  static String pickAnswer(List<VocabItem> own, int seed) {
    final fromLearner = {
      for (final w in own)
        if (w.german.length == wordLength && isValidGuess(clean(w.german)))
          clean(w.german),
    }.toList()
      ..sort();
    final pool = fromLearner.length >= 3 ? fromLearner : _builtIn;
    return pool[math.Random(seed).nextInt(pool.length)];
  }

  static const _builtIn = [
    'APFEL',
    'BLUME',
    'BRIEF',
    'DANKE',
    'FRAGE',
    'GLÜCK',
    'HEUTE',
    'KATZE',
    'LEBEN',
    'MILCH',
    'NACHT',
    'REISE',
    'STUHL',
    'TASSE',
    'TISCH',
    'VATER',
    'WOCHE',
    'FARBE',
    'GABEL',
    'HAFEN',
    'KARTE',
    'KLEID',
    'LAMPE',
    'NUDEL',
    'RADIO',
    'STADT',
    'STERN',
    'TRAUM',
    'WIESE',
    'BIRNE',
    'FISCH',
    'FLUSS',
    'SONNE',
    'REGEN',
    'WOLKE',
    'LICHT',
    'SPIEL',
    'SPORT',
    'MUSIK',
    'KÜCHE',
    'MONAT',
    'ZUNGE',
    'STEIN',
    'SCHAF',
    'PFERD',
    'BAUER',
    'BETTE',
    'SCHUH',
    'HOSEN',
  ];
}
