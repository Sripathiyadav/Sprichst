import '../learning/exercise_evaluator.dart';
import '../models/learning_models.dart';

/// The mini-games.
enum GameId { articleSwipe, memoryMatch, wordScramble, wortle, dialogue }

extension GameInfo on GameId {
  String get title => switch (this) {
        GameId.articleSwipe => 'Artikel-Rausch',
        GameId.memoryMatch => 'Memory',
        GameId.wordScramble => 'Buchstabensalat',
        GameId.wortle => 'Wortle',
        GameId.dialogue => 'Gespräch',
      };

  String get tagline => switch (this) {
        GameId.articleSwipe => 'Swipe der, die or das before time runs out.',
        GameId.memoryMatch => 'Match German words with their meanings.',
        GameId.wordScramble => 'Unscramble the letters into a word.',
        GameId.wortle => 'Guess the five-letter word in six tries.',
        GameId.dialogue => 'Pick the right reply in a real conversation.',
      };

  /// The skill the game trains, shown to the learner and used for statistics.
  SkillArea get area => switch (this) {
        GameId.articleSwipe => SkillArea.grammar,
        GameId.memoryMatch => SkillArea.vocabulary,
        GameId.wordScramble => SkillArea.writing,
        GameId.wortle => SkillArea.vocabulary,
        GameId.dialogue => SkillArea.reading,
      };
}

/// Chains of correct answers raise the multiplier, so streaks feel rewarding and
/// one slip costs the bonus but not the points already earned.
class ComboMeter {
  ComboMeter();

  static const maxMultiplier = 3.0;

  int _combo = 0;
  var _best = 0;

  int get combo => _combo;
  int get best => _best;

  /// 1.0 at the start, +0.5 for every three correct in a row, up to 3.0.
  double get multiplier =>
      (1 + (_combo ~/ 3) * .5).clamp(1.0, maxMultiplier).toDouble();

  /// Registers a correct answer and returns the points it earns for [base].
  int hit(int base) {
    final points = (base * multiplier).round();
    _combo++;
    if (_combo > _best) _best = _combo;
    return points;
  }

  void miss() => _combo = 0;
}

/// What a finished game reports back to the app.
class GameOutcome {
  const GameOutcome({
    required this.game,
    required this.score,
    required this.correct,
    required this.total,
    required this.stars,
    required this.bestCombo,
    required this.results,
  });

  final GameId game;
  final int score;
  final int correct;
  final int total;

  /// 0 to 3.
  final int stars;
  final int bestCombo;

  /// One result per question, so a game feeds the same skill statistics as a
  /// lesson. Game questions are not curriculum exercises, so they never create
  /// review items.
  final List<ExerciseResult> results;

  /// XP for finishing: about a tenth of the score, with a small floor for
  /// trying, capped so a game cannot out-earn the lessons.
  int get xp => correct == 0 ? 0 : (score ~/ 10).clamp(2, 40);
}

/// A throwaway exercise describing a game question, so results can use the
/// shared evaluator types.
Exercise gameQuestion({
  required String id,
  required String prompt,
  required String answer,
  required List<String> skills,
  required SkillArea area,
  List<String> options = const [],
  ExerciseKind kind = ExerciseKind.multipleChoice,
}) =>
    Exercise(
      id: 'game:$id',
      prompt: prompt,
      answer: answer,
      options: options,
      explanation: '',
      skills: skills,
      area: area,
      kind: kind,
    );

ExerciseResult gameResult(Exercise question, String response, bool correct) =>
    ExerciseResult(
      exercise: question,
      response: response,
      isCorrect: correct,
      feedback: correct ? 'Correct!' : 'Answer: ${question.answer}',
    );
