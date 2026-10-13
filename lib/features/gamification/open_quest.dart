import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/games/game_models.dart';
import '../../domain/learning/achievements.dart';
import '../flashcards/flashcard_session_view.dart';
import '../games/open_game.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';

/// Starts [quest]: the next lesson, a flashcard session, one of today's
/// games or a practice round, whichever the quest asks for.
void openQuest(BuildContext context, WidgetRef ref, Quest quest) {
  final app = ref.read(appControllerProvider);
  switch (quest.kind) {
    case QuestKind.lesson:
      // The quest is to finish a lesson, so it opens the next lesson of the
      // course, never a review or weak-skill round (those stay on the plan card).
      final lesson = app.recommendation?.lesson ?? app.currentLesson;
      if (lesson != null) {
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => LessonView(lesson: lesson)));
      } else {
        ref.read(shellTabRequestProvider.notifier).state = 1; // Learn
      }
    case QuestKind.cards:
      openFlashcards(context, ref);
    case QuestKind.games:
      // A different game each day, from the ones that need only words.
      const games = [
        GameId.articleSwipe,
        GameId.memoryMatch,
        GameId.wordScramble,
        GameId.wortle,
      ];
      if (app.gameWords().isEmpty) {
        ref.read(shellTabRequestProvider.notifier).state = 2; // Practice
      } else {
        openGame(context, ref, games[DateTime.now().day % games.length]);
      }
    case QuestKind.correct:
      openPractice(context, ref, title: 'Practice');
  }
}
