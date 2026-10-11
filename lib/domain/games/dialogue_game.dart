import 'dart:math' as math;

import '../models/dialogue_models.dart';
import '../models/learning_models.dart';
import 'game_models.dart';

/// Gespräch: a short everyday conversation where the learner supplies their own
/// lines. Partner lines appear on their own; each learner gap asks for a reply
/// from a few candidates, so the learner reads, chooses and sees the whole
/// exchange assemble — the Goethe Sprechen "Bitte formulieren" idea, at a
/// recognition level.
class DialogueGame {
  DialogueGame(this.dialogue, math.Random random) {
    _options = {
      for (var i = 0; i < dialogue.turns.length; i++)
        if (dialogue.turns[i].isLearner)
          i: ([...dialogue.turns[i].options]..shuffle(random)),
    };
  }

  static const basePoints = 15;

  final Dialogue dialogue;
  final combo = ComboMeter();
  late final Map<int, List<String>> _options;
  final Map<int, String> _chosen = {};
  var _index = 0;
  var _score = 0;
  var _correct = 0;

  /// Turns seen so far, in order. Look up the learner's replies with [chosenAt].
  List<DialogueTurn> get visible =>
      dialogue.turns.sublist(0, math.min(_index + 1, dialogue.turns.length));

  /// Index of the turn the game is up to.
  int get cursor => _index;

  int get score => _score;
  bool get isOver => _index >= dialogue.turns.length;

  /// Index of the gap currently waiting for a reply, or null when the next turn
  /// is a partner line (which [advance] reveals) or the dialogue is over.
  DialogueTurn? get pending {
    if (isOver) return null;
    final turn = dialogue.turns[_index];
    return turn.isLearner ? turn : null;
  }

  List<String> get options => _options[_index] ?? const [];

  String? chosenAt(int turn) => _chosen[turn];

  /// Moves past partner lines until a learner gap (or the end) is reached.
  void advance() {
    while (!isOver && !dialogue.turns[_index].isLearner) {
      _index++;
    }
  }

  /// Answers the pending gap; a wrong choice scores nothing but the right line
  /// is still shown so the exchange reads correctly.
  bool reply(String option) {
    final turn = pending;
    if (turn == null) return false;
    final right = option == turn.answer;
    _chosen[_index] = option;
    if (right) {
      _correct++;
      _score += combo.hit(basePoints);
    } else {
      combo.miss();
    }
    _index++;
    return right;
  }

  GameOutcome finish() {
    final gaps = dialogue.gapCount;
    final ratio = gaps == 0 ? 0.0 : _correct / gaps;
    return GameOutcome(
      game: GameId.dialogue,
      score: _score,
      correct: _correct,
      total: gaps,
      stars: ratio >= .99
          ? 3
          : ratio >= .66
              ? 2
              : ratio >= .34
                  ? 1
                  : 0,
      bestCombo: combo.best,
      results: [
        for (final entry in _chosen.entries)
          gameResult(
            gameQuestion(
              id: 'dialogue/${dialogue.id}/${entry.key}',
              prompt: dialogue.turns[entry.key].intent ?? '',
              answer: dialogue.turns[entry.key].answer!,
              skills: const ['speaking_practice'],
              area: SkillArea.speaking,
              options: dialogue.turns[entry.key].options,
            ),
            entry.value,
            entry.value == dialogue.turns[entry.key].answer,
          ),
      ],
    );
  }
}

/// Dialogues suited to a learner: at or below their level, preferring those on
/// their goal topics, easiest first among equals.
List<Dialogue> dialoguesFor(
  List<Dialogue> all,
  CefrLevel level,
  Set<String> topics,
) {
  final fits = all.where((d) => d.level.index <= level.index).toList();
  final pool = fits.isEmpty ? [...all] : fits;
  int rank(Dialogue d) =>
      (d.topics.any(topics.contains) ? 0 : 10) + (level.index - d.level.index);
  return pool..sort((a, b) => rank(a).compareTo(rank(b)));
}
