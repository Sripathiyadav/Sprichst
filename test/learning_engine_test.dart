import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/data/profile_codec.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/exercise_session.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

final seedLessons = loadCourse();

const _article = Exercise(
  id: 'article_x',
  prompt: 'Choose: ___ Tisch',
  options: ['der', 'die', 'das'],
  answer: 'der',
  explanation: 'Tisch is masculine.',
  skills: ['definite_articles'],
  area: SkillArea.grammar,
);

const _typed = Exercise(
  id: 'typed_x',
  kind: ExerciseKind.translation,
  prompt: 'Translate: Good morning',
  answer: 'Guten Morgen',
  alternatives: ['Morgen'],
  explanation: 'A morning greeting.',
  skills: ['greetings'],
);

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.a1);

ExerciseResult _answer(Exercise exercise, String response) =>
    const ExerciseEvaluator().evaluate(exercise, response);

void main() {
  const evaluator = ExerciseEvaluator();
  const tracker = ProgressTracker();
  final now = DateTime(2026, 10, 7, 9);

  group('ExerciseEvaluator', () {
    test('accepts the answer ignoring whitespace and trailing punctuation', () {
      expect(
          evaluator.evaluate(_typed, '  Guten   Morgen! ').isCorrect, isTrue);
    });

    test('accepts listed alternatives', () {
      expect(evaluator.evaluate(_typed, 'Morgen').isCorrect, isTrue);
    });

    test('rejects a case-only difference and says why', () {
      final result = evaluator.evaluate(_typed, 'guten morgen');
      expect(result.isCorrect, isFalse);
      expect(result.feedback, contains('capitalisation'));
    });

    test('rejects wrong answers and reveals the correct one', () {
      final result = evaluator.evaluate(_article, 'die');
      expect(result.isCorrect, isFalse);
      expect(result.feedback, contains('der'));
    });
  });

  group('ExerciseSession', () {
    test('requires checking before advancing and finishes after the last', () {
      final session = ExerciseSession([_article, _typed]);
      expect(() => session.advance(), throwsStateError);

      expect(session.submit('der').isCorrect, isTrue);
      expect(() => session.submit('der'), throwsStateError);
      session.advance();
      session.submit('wrong');
      session.advance();

      expect(session.isFinished, isTrue);
      expect(session.correctCount, 1);
      expect(session.results, hasLength(2));
    });
  });

  group('Curriculum', () {
    final curriculum = Curriculum(seedLessons);

    test('groups lessons into units by level and title', () {
      expect(curriculum.units.map((u) => u.title),
          ['First steps', 'Daily life', 'Sentences']);
      expect(curriculum.units.first.lessons, hasLength(3));
    });

    test('computes level progress from completed lessons', () {
      expect(
          curriculum.levelProgress(
              CefrLevel.preA1, (id) => id == 'pre_a1_greetings'),
          closeTo(1 / 3, 1e-9));
      expect(curriculum.levelProgress(CefrLevel.c1, (_) => true), 0);
    });

    test('finds the first incomplete lesson, staying on the last when done',
        () {
      expect(curriculum.firstIncomplete((id) => id == 'pre_a1_greetings')!.id,
          'pre_a1_introductions');
      expect(curriculum.firstIncomplete((_) => true)!.id, 'a1_accusative');
    });

    test('interleaves exercises across skills without duplicates', () {
      final picked = curriculum
          .exercisesForSkills(['introductions', 'definite_articles'], limit: 4);
      final ids = picked.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(picked.first.skills, contains('introductions'));
      expect(picked[1].skills, contains('definite_articles'));
      expect(curriculum.exercisesForSkills(['nope']), isEmpty);
    });
  });

  group('ProgressTracker', () {
    final curriculum = Curriculum(seedLessons);
    final lesson = seedLessons.first;

    test('completing a lesson records progress, advances, and awards XP once',
        () {
      final results = [
        for (final exercise in lesson.exercises)
          _answer(exercise, exercise.answer),
      ];
      final first = tracker
          .completeLesson(_learner(), lesson, curriculum, results, now: now);

      expect(first.xpEarned, 30);
      expect(first.profile.isLessonCompleted(lesson.id), isTrue);
      expect(first.profile.currentLessonId, 'pre_a1_introductions');
      expect(first.profile.streak, 1);

      final replay = tracker
          .completeLesson(first.profile, lesson, curriculum, results, now: now);
      expect(replay.xpEarned, 0);
      expect(replay.profile.lessonProgress[lesson.id]!.attempts, 2);
      expect(replay.profile.currentLessonId, 'pre_a1_introductions');
    });

    test('mistakes feed skill stats, recent mistakes, and a review item', () {
      final update = tracker
          .completePractice(_learner(), [_answer(_article, 'die')], now: now);

      expect(update.xpEarned, 0);
      expect(update.profile.skillStats['definite_articles']!.attempts, 1);
      expect(update.profile.recentMistakes.single,
          startsWith('Definite articles:'));
      final review = update.profile.reviewItems.single;
      expect(review.id, 'exercise-article_x');
      expect(review.kind, ReviewItem.mistakeKind);
      expect(review.dueAt, now.add(ProgressTracker.mistakeReviewDelay));
    });

    test('weak skills need evidence and are ranked weakest first', () {
      var profile = _learner();
      profile = tracker
          .completePractice(profile, [_answer(_article, 'die')], now: now)
          .profile;
      expect(tracker.weakSkills(profile), isEmpty,
          reason: 'one answer is not enough');

      profile = tracker
          .completePractice(profile,
              [_answer(_article, 'die'), _answer(_typed, 'Guten Morgen')],
              now: now)
          .profile;
      expect(tracker.weakSkills(profile), ['definite_articles']);
    });

    test('recent mistakes are capped and deduplicated', () {
      var profile = _learner();
      for (var i = 0; i < 15; i++) {
        final exercise = Exercise(
          id: 'e$i',
          prompt: 'Prompt $i',
          answer: 'a',
          options: const ['a', 'b'],
          explanation: '',
          skills: const ['s'],
        );
        profile = tracker
            .completePractice(profile, [_answer(exercise, 'b')], now: now)
            .profile;
      }
      expect(
          profile.recentMistakes, hasLength(ProgressTracker.maxRecentMistakes));
      expect(profile.recentMistakes.last, contains('Prompt 14'));
    });

    test(
        'streak grows on consecutive days, holds within a day, resets after a gap',
        () {
      var profile = tracker
          .completePractice(_learner(), [_answer(_article, 'der')], now: now)
          .profile;
      expect(profile.streak, 1);

      profile = tracker
          .completePractice(profile, [_answer(_article, 'der')],
              now: now.add(const Duration(hours: 5)))
          .profile;
      expect(profile.streak, 1);

      profile = tracker
          .completePractice(profile, [_answer(_article, 'der')],
              now: now.add(const Duration(days: 1)))
          .profile;
      expect(profile.streak, 2);
      expect(profile.streakAt(now.add(const Duration(days: 2))), 2);
      expect(profile.streakAt(now.add(const Duration(days: 3))), 0);

      profile = tracker
          .completePractice(profile, [_answer(_article, 'der')],
              now: now.add(const Duration(days: 9)))
          .profile;
      expect(profile.streak, 1);
    });

    test('startLesson is idempotent', () {
      final started = tracker.startLesson(_learner(), lesson);
      expect(
          started.lessonProgress[lesson.id]!.status, LessonStatus.inProgress);
      expect(identical(tracker.startLesson(started, lesson), started), isTrue);
    });
  });

  group('ProfileCodec', () {
    DateTime decode(Object? raw) => DateTime.parse(raw as String);
    Object encode(DateTime date) => date.toIso8601String();

    test('round-trips a profile with progress and stats', () {
      final profile = tracker
          .completePractice(_learner(), [_answer(_article, 'die')], now: now)
          .profile
          .copyWith(
        lessonProgress: const {
          'a': LessonProgress(
              status: LessonStatus.completed,
              attempts: 2,
              bestCorrect: 3,
              total: 3),
        },
        appearancePreference: AppearancePreference.dark,
      );

      final decoded = ProfileCodec.decode(
        ProfileCodec.encode(profile, encodeDate: encode),
        decodeDate: decode,
      );

      expect(decoded.lessonProgress['a']!.bestCorrect, 3);
      expect(decoded.skillStats['definite_articles']!.attempts, 1);
      expect(decoded.recentMistakes, profile.recentMistakes);
      expect(
          decoded.reviewItems.single.dueAt, profile.reviewItems.single.dueAt);
      expect(decoded.lastStudyDate, profile.lastStudyDate);
      expect(decoded.appearancePreference, AppearancePreference.dark);
    });

    test('migrates documents saved before lesson progress existed', () {
      final decoded = ProfileCodec.decode({
        'name': 'Sam',
        'currentLevel': 'a1',
        'completedLessonIds': ['pre_a1_greetings'],
        'vocabulary': .6,
      }, decodeDate: decode);

      expect(decoded.name, 'Sam');
      expect(decoded.currentLevel, CefrLevel.a1);
      expect(decoded.isLessonCompleted('pre_a1_greetings'), isTrue);
      expect(decoded.scores.vocabulary, .6);
      expect(decoded.speechRate, 230);
    });
  });

  group('seed curriculum', () {
    test('has unique ids and self-consistent exercises', () {
      final lessonIds = seedLessons.map((l) => l.id).toList();
      expect(lessonIds.toSet(), hasLength(lessonIds.length));

      final exercises = [for (final l in seedLessons) ...l.exercises];
      expect(exercises.map((e) => e.id).toSet(), hasLength(exercises.length));

      for (final exercise in exercises) {
        expect(exercise.skills, isNotEmpty, reason: exercise.id);
        if (exercise.kind == ExerciseKind.multipleChoice) {
          expect(exercise.options, contains(exercise.answer),
              reason: exercise.id);
        }
        if (exercise.kind == ExerciseKind.wordOrder) {
          expect(exercise.options.toList()..sort(),
              exercise.answer.split(' ').toList()..sort(),
              reason: exercise.id);
        }
        expect(_answer(exercise, exercise.answer).isCorrect, isTrue,
            reason: exercise.id);
      }
    });
  });
}
