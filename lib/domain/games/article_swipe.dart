import 'dart:math' as math;

import 'game_models.dart';
import '../models/learning_models.dart';

const articles = ['der', 'die', 'das'];

/// Artikel-Rausch: nouns fly past and the learner sorts them into der, die or
/// das. Genders have no reliable rule, so speed and repetition are the way in.
///
/// The game is a pure state machine; the widget feeds it answers and clock
/// ticks. A round ends when the cards or the time run out.
class ArticleSwipeGame {
  ArticleSwipeGame(List<VocabItem> nouns, {int cards = 20, int seconds = 60})
      : _cards = nouns.where((n) => n.isNoun).take(cards).toList(),
        _remaining = Duration(seconds: seconds) {
    assert(_cards.isNotEmpty, 'ArticleSwipeGame needs at least one noun');
  }

  /// Picks and shuffles from [pool] with [random].
  factory ArticleSwipeGame.draw(
    List<VocabItem> pool,
    math.Random random, {
    int cards = 20,
    int seconds = 60,
  }) =>
      ArticleSwipeGame(
        ([...pool.where((n) => n.isNoun)]..shuffle(random)),
        cards: cards,
        seconds: seconds,
      );

  static const basePoints = 10;

  final List<VocabItem> _cards;
  final combo = ComboMeter();
  final List<(VocabItem, String, bool)> _answers = [];
  Duration _remaining;
  var _index = 0;
  var _score = 0;

  int get total => _cards.length;
  int get answered => _answers.length;
  int get score => _score;
  int get correct => _answers.where((a) => a.$3).length;
  Duration get remaining => _remaining;
  bool get isOver => _index >= _cards.length || _remaining <= Duration.zero;

  /// The noun on screen, or null once the round is over.
  VocabItem? get current => isOver ? null : _cards[_index];

  /// Returns whether [article] was right. A wrong swipe keeps the learner on
  /// the card's lesson: the answer is shown by the caller, then the game moves on.
  bool answer(String article) {
    final card = current;
    if (card == null) return false;
    final right = article == card.article;
    _answers.add((card, article, right));
    if (right) {
      _score += combo.hit(basePoints);
    } else {
      combo.miss();
    }
    _index++;
    return right;
  }

  /// Advances the clock; the widget calls it once a second.
  void tick([Duration by = const Duration(seconds: 1)]) {
    if (isOver) return;
    _remaining -= by;
  }

  GameOutcome finish() {
    final ratio = answered == 0 ? 0.0 : correct / total;
    return GameOutcome(
      game: GameId.articleSwipe,
      score: _score,
      correct: correct,
      total: answered,
      stars: ratio >= .9
          ? 3
          : ratio >= .7
              ? 2
              : ratio >= .4
                  ? 1
                  : 0,
      bestCombo: combo.best,
      results: [
        for (final (card, given, right) in _answers)
          gameResult(
            gameQuestion(
              id: 'article/${card.id}',
              prompt: 'Article for ${card.german}',
              answer: card.article!,
              skills: const ['definite_articles'],
              area: SkillArea.grammar,
              options: articles,
            ),
            given,
            right,
          ),
      ],
    );
  }
}
