import 'dart:math' as math;

import '../models/learning_models.dart';
import 'game_models.dart';

/// One face-down tile. Two tiles with the same [pairId] match.
class MemoryTile {
  const MemoryTile({
    required this.pairId,
    required this.label,
    required this.isGerman,
  });

  final String pairId;
  final String label;
  final bool isGerman;
}

/// Memory: German words and their English meanings, face down. Flip two; a
/// match stays up, a miss turns back over (after the widget has shown it).
class MemoryMatchGame {
  MemoryMatchGame(List<VocabItem> words, math.Random random, {int pairs = 6}) {
    final chosen = ([...words]..shuffle(random)).take(pairs).toList();
    tiles = [
      for (final w in chosen) ...[
        MemoryTile(pairId: w.id, label: w.display, isGerman: true),
        MemoryTile(pairId: w.id, label: w.english, isGerman: false),
      ]
    ]..shuffle(random);
  }

  late final List<MemoryTile> tiles;
  final Set<int> _matched = {};
  final List<int> _faceUp = [];
  var _moves = 0;
  var _misses = 0;

  int get moves => _moves;
  int get pairs => tiles.length ~/ 2;
  bool get isOver => _matched.length == tiles.length;
  bool get isResolving => _faceUp.length == 2;
  List<int> get faceUp => List.unmodifiable(_faceUp);

  bool isMatched(int i) => _matched.contains(i);
  bool isShown(int i) => _matched.contains(i) || _faceUp.contains(i);

  /// Flips tile [i]. Returns null while a pair is still on show or the tile is
  /// not flippable; otherwise whether this flip completed a matching pair
  /// (`true`), a mismatch (`false`), or only turned the first tile (`null`).
  /// Use [isResolving] to tell the last two apart.
  bool? flip(int i) {
    if (i < 0 || i >= tiles.length || isShown(i) || isResolving) return null;
    _faceUp.add(i);
    if (_faceUp.length < 2) return null;
    _moves++;
    final a = _faceUp[0], b = _faceUp[1];
    final match = tiles[a].pairId == tiles[b].pairId;
    if (match) {
      _matched
        ..add(a)
        ..add(b);
      _faceUp.clear();
    } else {
      _misses++;
    }
    return match;
  }

  /// Turns a mismatched pair back down once the learner has seen it.
  void hideMismatch() {
    if (isResolving) _faceUp.clear();
  }

  GameOutcome finish() {
    // A perfect game takes `pairs` moves; every extra move costs 15 points.
    final score = math.max(0, pairs * 30 - _misses * 15);
    final stars = _misses <= 1
        ? 3
        : _misses <= pairs
            ? 2
            : 1;
    return GameOutcome(
      game: GameId.memoryMatch,
      score: isOver ? score : 0,
      correct: _matched.length ~/ 2,
      total: pairs,
      stars: isOver ? stars : 0,
      bestCombo: 0,
      results: [
        for (var i = 0; i < tiles.length; i++)
          if (tiles[i].isGerman && isMatched(i))
            gameResult(
              gameQuestion(
                id: 'memory/${tiles[i].pairId}',
                prompt: tiles[i].label,
                answer: tiles[i].label,
                skills: const ['vocabulary'],
                area: SkillArea.vocabulary,
              ),
              tiles[i].label,
              true,
            ),
      ],
    );
  }
}
