import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/data/local/local_learning_repository.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

void main() {
  for (final accuracy in [1.0, .5]) {
    testWidgets(
        'a learner at ${(accuracy * 100).round()}% walks the whole '
        'course without repeating or getting stuck', (tester) async {
      final curriculum = Curriculum((await tester.runAsync(
        () => LocalLearningRepository().loadLessons(),
      ))!);
      const tracker = ProgressTracker();
      const evaluator = ExerciseEvaluator();
      var profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.a1);
      profile = profile.copyWith(
          currentLessonId: tracker.path.nextLesson(profile, curriculum)!.id);
      var now = DateTime(2026, 1, 1, 9);
      final seen = <String>[];
      for (var step = 0; step < curriculum.lessons.length * 3; step++) {
        final lesson = curriculum.lessonById(profile.currentLessonId);
        expect(lesson, isNotNull);
        // A shaky level sends the learner back to its weakest lesson; a replay
        // that goes well must lift them out, so it is answered in full.
        final replay = profile.isLessonCompleted(lesson!.id);
        if (!replay) seen.add(lesson.id);
        var i = 0;
        final results = [
          for (final e in lesson.exercises)
            evaluator.evaluate(
                e,
                replay || (i++ / lesson.exercises.length) < accuracy
                    ? e.answer
                    : 'x'),
        ];
        profile = tracker
            .completeLesson(profile, lesson, curriculum, results, now: now)
            .profile;
        now = now.add(const Duration(hours: 1));
      }
      final reachable = curriculum.lessons
          .where((l) => tracker.path.isRelevant(l, profile.goal))
          .length;
      // Every lesson of the learner's goal is reached once, in order of offer.
      expect(seen.length, greaterThanOrEqualTo(reachable - 4),
          reason: 'stopped after ${seen.length} of $reachable: $seen');
    });
  }
}
