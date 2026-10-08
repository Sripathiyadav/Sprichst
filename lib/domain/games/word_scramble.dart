import 'dart:math' as math;

import '../learning/speech_matcher.dart';
import '../models/learning_models.dart';
import 'game_models.dart';

/// Buchstabensalat: the letters of a word, shuffled. The English meaning is the
/// clue; a hint reveals the next letter at a cost.
class ScrambleRound {
  const ScrambleRound({required this.word, required this.letters});

  final VocabItem word;
  final List<String> letters;

  String get target => word.german;
}

class WordScrambleGame {
  WordScrambleGame(List<VocabItem> words, math.Random random,
      {int rounds = 6}) {
    final usable = words.where((w) => _isPlayable(w.german)).toList()
      ..shuffle(random);
    this.rounds = [
      for (final w in usable.take(rounds))
        ScrambleRound(word: w, letters: scramble(w.german, random)),
    ];
  }

  static const basePoints = 20;
  static const hintCost = 8;

  late final List<ScrambleRound> rounds;
  final combo = ComboMeter();
  final List<(ScrambleRound, String, bool)> _done = [];
  var _index = 0;
  var _score = 0;
  var _hints = 0;

  int get score => _score;
  int get index => _index;
  bool get isOver => _index >= rounds.length;
  ScrambleRound? get current => isOver ? null : rounds[_index];

  /// How many letters of the current word the learner has been shown.
  int get hintsShown => _hints;
  String get hintText => current == null
      ? ''
      : current!.target.substring(0, math.min(_hints, current!.target.length));

  void hint() {
    final round = current;
    if (round == null || _hints >= round.target.length - 1) return;
    _hints++;
  }

  /// Checks a guess (case, spacing and umlaut spelling are forgiven). A wrong
  /// guess leaves the round open; [skip] gives it up.
  bool guess(String text) {
    final round = current;
    if (round == null) return false;
    final right =
        SpeechMatcher.normalise(text) == SpeechMatcher.normalise(round.target);
    if (!right) {
      combo.miss();
      return false;
    }
    _score += math.max(5, combo.hit(basePoints) - _hints * hintCost);
    _advance(text, true);
    return true;
  }

  void skip() {
    if (current == null) return;
    combo.miss();
    _advance('', false);
  }

  void _advance(String given, bool right) {
    _done.add((rounds[_index], given, right));
    _index++;
    _hints = 0;
  }

  GameOutcome finish() {
    final correct = _done.where((d) => d.$3).length;
    final ratio = rounds.isEmpty ? 0.0 : correct / rounds.length;
    return GameOutcome(
      game: GameId.wordScramble,
      score: _score,
      correct: correct,
      total: _done.length,
      stars: ratio >= .9
          ? 3
          : ratio >= .6
              ? 2
              : ratio >= .3
                  ? 1
                  : 0,
      bestCombo: combo.best,
      results: [
        for (final (round, given, right) in _done)
          gameResult(
            gameQuestion(
              id: 'scramble/${round.word.id}',
              prompt: 'Unscramble: ${round.word.english}',
              answer: round.target,
              skills: const ['vocabulary'],
              area: SkillArea.writing,
              kind: ExerciseKind.fillBlank,
            ),
            given,
            right,
          ),
      ],
    );
  }

  static bool _isPlayable(String word) =>
      word.length >= 4 && word.length <= 9 && !word.contains(' ');

  /// Shuffles [word]'s letters so the result differs from the word. Words made
  /// of one repeated letter cannot differ, so they are returned as they are.
  static List<String> scramble(String word, math.Random random) {
    final letters = word.split('');
    if (letters.toSet().length < 2) return letters;
    List<String> shuffled;
    do {
      shuffled = [...letters]..shuffle(random);
    } while (shuffled.join() == word);
    return shuffled;
  }
}
