import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/domain/learning/achievements.dart';
import 'package:sprichst/domain/learning/adaptive_planner.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/data/local/local_learning_repository.dart';
import 'package:sprichst/features/gamification/open_quest.dart';
import 'package:sprichst/features/learn/lesson_view.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
      'the lesson quest opens the next lesson, not the review that is due',
      (tester) async {
    final curriculum = Curriculum((await tester.runAsync(
      () => LocalLearningRepository().loadLessons(),
    ))!);
    final first = curriculum.lessonsAt(CefrLevel.a1).first;
    // Finish the first lesson with every answer wrong: reviews are now due.
    var profile = LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1);
    final done = const ProgressTracker().completeLesson(
      profile,
      first,
      curriculum,
      [
        for (final e in first.exercises)
          const ExerciseEvaluator().evaluate(e, 'x'),
      ],
      now: DateTime.now().subtract(const Duration(hours: 1)),
    );
    profile = done.profile;
    final next = profile.currentLessonId;
    expect(next, isNot(first.id));

    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(InMemoryLearningRepository(profile)),
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            ref.watch(appControllerProvider);
            return TextButton(
              onPressed: () => openQuest(
                  context,
                  ref,
                  const Quest(
                      kind: QuestKind.lesson,
                      title: 'Finish a lesson',
                      target: 1,
                      xp: 15)),
              child: const Text('go'),
            );
          },
        ),
      ),
    ));
    await tester.runAsync(() async {
      final context = tester.element(find.text('go'));
      await ProviderScope.containerOf(context)
          .read(appControllerProvider)
          .initialize();
    });
    // The plan card sends the learner to a review first; the quest must not.
    expect(
        ProviderScope.containerOf(tester.element(find.text('go')))
            .read(appControllerProvider)
            .plan
            ?.kind,
        PlanKind.review);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final view = tester.widget<LessonView>(find.byType(LessonView));
    expect(view.lesson.id, next);
  });
}
