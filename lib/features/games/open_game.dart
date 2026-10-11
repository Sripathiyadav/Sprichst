import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/games/game_models.dart';
import '../../domain/games/wortle.dart';
import 'article_swipe_view.dart';
import 'dialogue_game_view.dart';
import 'game_page.dart';
import 'memory_match_view.dart';
import 'word_scramble_view.dart';
import 'wortle_view.dart';

/// Opens [game], built from the words the learner has met.
void openGame(BuildContext context, WidgetRef ref, GameId game,
    {int? dialogueIndex}) {
  final app = ref.read(appControllerProvider);
  final GameBuilder builder;
  switch (game) {
    case GameId.articleSwipe:
      final nouns = app.gameNouns();
      builder = (_, done) => ArticleSwipeView(nouns: nouns, onFinished: done);
    case GameId.memoryMatch:
      final words = app.gameWords();
      builder = (_, done) => MemoryMatchView(words: words, onFinished: done);
    case GameId.wordScramble:
      final words = app.gameWords();
      builder = (_, done) => WordScrambleView(words: words, onFinished: done);
    case GameId.wortle:
      final words = app.gameWords();
      builder = (_, done) => WortleView(
            answer:
                WortleGame.pickAnswer(words, math.Random().nextInt(1 << 30)),
            onFinished: done,
          );
    case GameId.dialogue:
      final all = app.dialoguesForLearner();
      if (all.isEmpty) return;
      var next = dialogueIndex ?? 0;
      builder = (_, done) {
        final dialogue = all[next++ % all.length];
        return DialogueGameView(dialogue: dialogue, onFinished: done);
      };
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => GamePage(game: game, builder: builder),
  ));
}
