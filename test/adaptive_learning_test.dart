import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/core/services/review_scheduler.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/profile_codec.dart';
import 'package:sprichst/domain/learning/adaptive_planner.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/exercise_session.dart';
import 'package:sprichst/domain/learning/learning_path.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/learning/tutor_context_builder.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

final _course = Curriculum(loadCourse());
const _tracker = ProgressTracker();
const _path = LearningPath();
const _planner = AdaptivePlanner();
final _now = DateTime(2026, 10, 7, 9);

LearningProfile _learner([CefrLevel level = CefrLevel.preA1]) =>
    LearningProfile.newLearner(nativeLanguage: 'English', currentLevel: level);

Lesson _lesson(String id) => _course.lessonById(id)!;

/// Answers every exercise in [lesson] correctly, except those in [wrong].
List<ExerciseResult> _answers(Lesson lesson, {Set<String> wrong = const {}}) =>
    [
      for (final e in lesson.exercises)
        const ExerciseEvaluator()
            .evaluate(e, wrong.contains(e.id) ? '§wrong§' : e.answer),
    ];

LearningProfile _complete(
  LearningProfile profile,
  String lessonId, {
  Set<String> wrong = const {},
}) {
  final lesson = _lesson(lessonId);
  return _tracker
      .completeLesson(profile, lesson, _course, _answers(lesson, wrong: wrong),
          now: _now)
      .profile;
}

void main() {
  group('LearningPath', () {
    test('a learner who chooses A1 starts at the first A1 lesson', () {
      expect(
          _path.nextLesson(_learner(CefrLevel.a1), _course)!.id, 'a1_articles');
      expect(_path.nextLesson(_learner(), _course)!.id, 'pre_a1_greetings');
    });

    test('finishing a level with good accuracy earns the next level', () {
      var profile = _learner(CefrLevel.a1);
      for (final lesson in _course.lessonsAt(CefrLevel.a1)) {
        profile = _complete(profile, lesson.id);
      }
      expect(_path.earnedLevel(profile, _course), CefrLevel.a2);
    });

    test('finishing a level shakily revisits its weakest lesson instead', () {
      // Miss every exercise in four of the seven A1 lessons: average accuracy
      // is well under the promotion bar.
      const weakLessons = {
        'a1_word_order',
        'a1_sein',
        'a1_haben',
        'a1_accusative'
      };
      var profile = _learner(CefrLevel.a1);
      for (final lesson in _course.lessonsAt(CefrLevel.a1)) {
        profile = _complete(
          profile,
          lesson.id,
          wrong: weakLessons.contains(lesson.id)
              ? {for (final e in lesson.exercises) e.id}
              : const {},
        );
      }

      expect(_path.earnedLevel(profile, _course), CefrLevel.a1);
      final next = _path.nextLesson(profile, _course)!;
      expect(next.level, CefrLevel.a1);
      expect(profile.lessonProgress[next.id]!.bestAccuracy, 0);
    });

    test('completing the last core lesson at a level reports the level-up', () {
      var profile = _learner(CefrLevel.a1);
      // Exam-prep lessons are optional for an everyday learner, so only the core
      // A1 lessons gate the move up.
      final core = [
        for (final l in _course.lessonsAt(CefrLevel.a1))
          if (_path.isRelevant(l, profile.goal)) l,
      ];
      for (final lesson in core.take(core.length - 1)) {
        profile = _complete(profile, lesson.id);
      }
      final last = core.last;
      final update = _tracker
          .completeLesson(profile, last, _course, _answers(last), now: _now);

      expect(update.leveledUpTo, CefrLevel.a2);
      expect(update.profile.currentLevel, CefrLevel.a2);
      expect(_course.lessonById(update.profile.currentLessonId)!.level,
          CefrLevel.a2);
    });

    test('a retake does not move the learner backwards', () {
      var profile = _complete(_learner(), 'pre_a1_greetings');
      final next = profile.currentLessonId;
      profile = _complete(profile, 'pre_a1_greetings');
      expect(profile.currentLessonId, next);
    });
  });

  group('AdaptivePlanner', () {
    test('practises only lessons the learner has started', () {
      final fresh = _learner();
      expect(_planner.buildSession(fresh, _course, now: _now), isEmpty);

      final started = _tracker.startLesson(fresh, _lesson('pre_a1_greetings'));
      final session = _planner.buildSession(started, _course, now: _now);
      expect(session, isNotEmpty);
      expect(
        session.every(
            (e) => _course.lessonOfExercise(e.id)!.id == 'pre_a1_greetings'),
        isTrue,
      );
    });

    test('plans a lesson, then weak skills, then review of due misses', () {
      expect(
          _planner.plan(_learner(), _course, now: _now)!.kind, PlanKind.lesson);

      // One miss in three leaves "greetings" weak, but nothing is due yet.
      final profile =
          _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_1'});
      final now = _planner.plan(profile, _course, now: _now)!;
      expect(now.kind, PlanKind.practice);
      expect(now.skillIds, ['greetings']);

      final later = _now.add(const Duration(minutes: 11));
      final plan = _planner.plan(profile, _course, now: later)!;
      expect(plan.kind, PlanKind.review);
      expect(plan.title, startsWith('Review'));
    });

    test('a due missed exercise is selected for the session', () {
      final profile =
          _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_1'});
      final later = _now.add(const Duration(minutes: 11));
      final session = _planner.buildSession(profile, _course, now: later);
      expect(session.map((e) => e.id), contains('greeting_1'));
    });

    test('exercises just answered rank below ones not yet seen', () {
      final started =
          _tracker.startLesson(_learner(), _lesson('pre_a1_greetings'));
      // Answer only greeting_1 so greeting_2 / greeting_3 remain novel.
      final seen = _tracker
          .completePractice(
              started,
              _course,
              [
                const ExerciseEvaluator()
                    .evaluate(_course.exerciseById('greeting_1')!, 'Danke')
              ],
              now: _now)
          .profile;
      final session = _planner.buildSession(seen, _course, now: _now, limit: 2);
      expect(session.map((e) => e.id), isNot(contains('greeting_1')));
    });

    test('skill focus limits the session to that skill', () {
      var profile = _complete(_learner(CefrLevel.a1), 'a1_articles');
      profile = _complete(profile, 'a1_sein');
      final session = _planner
          .buildSession(profile, _course, now: _now, skillIds: ['sein']);
      expect(session, isNotEmpty);
      expect(session.every((e) => e.skills.contains('sein')), isTrue);
    });

    test('sessions mix skills and warm up from easy to hard', () {
      var profile = _complete(_learner(CefrLevel.a1), 'a1_articles');
      profile = _complete(profile, 'a1_sein');
      profile = _complete(profile, 'a1_haben');
      final session = _planner.buildSession(profile, _course, now: _now);

      final difficulties = session.map((e) => e.difficulty).toList();
      expect([...difficulties]..sort(), difficulties);
      expect(session.map((e) => e.skills.first).toSet().length, greaterThan(1));
    });

    test('difficulty target rises with demonstrated skill', () {
      expect(AdaptivePlanner.targetDifficulty(null), 1);
      expect(
          AdaptivePlanner.targetDifficulty(
              const SkillStat(attempts: 5, correct: 1)),
          1);
      expect(
          AdaptivePlanner.targetDifficulty(
              const SkillStat(attempts: 5, correct: 4)),
          2);
      expect(
          AdaptivePlanner.targetDifficulty(
              const SkillStat(attempts: 8, correct: 8)),
          3);
    });

    test('building a session is deterministic', () {
      final profile =
          _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_2'});
      List<String> ids() => _planner
          .buildSession(profile, _course, now: _now)
          .map((e) => e.id)
          .toList();
      expect(ids(), ids());
    });
  });

  group('review rescheduling from real answers', () {
    ExerciseResult answer(String id, bool correct) {
      final e = _course.exerciseById(id)!;
      return const ExerciseEvaluator()
          .evaluate(e, correct ? e.answer : '§wrong§');
    }

    test('a missed exercise answered correctly is spaced out, then retired',
        () {
      var profile =
          _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_1'});
      ReviewItem? item() => profile.reviewItems
          .where((i) => i.id == 'exercise-greeting_1')
          .firstOrNull;
      expect(item()!.intervalDays, 0);

      profile = _tracker
          .completePractice(profile, _course, [answer('greeting_1', true)],
              now: _now)
          .profile;
      expect(item()!.intervalDays, 3);
      expect(item()!.dueAt, _now.add(const Duration(days: 3)));

      profile = _tracker
          .completePractice(profile, _course, [answer('greeting_1', true)],
              now: _now.add(const Duration(days: 3)))
          .profile;
      expect(item(), isNull, reason: 'mastered after two successes');
    });

    test('missing it again brings it straight back', () {
      var profile =
          _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_1'});
      profile = _tracker
          .completePractice(profile, _course, [answer('greeting_1', true)],
              now: _now)
          .profile;
      profile = _tracker
          .completePractice(profile, _course, [answer('greeting_1', false)],
              now: _now)
          .profile;
      final item =
          profile.reviewItems.singleWhere((i) => i.id == 'exercise-greeting_1');
      expect(item.intervalDays, 0);
      expect(item.dueAt, _now.add(ProgressTracker.mistakeReviewDelay));
    });

    test('lesson recall is rated by accuracy on that lesson', () {
      var profile = _complete(_learner(), 'pre_a1_greetings');
      final lesson = _lesson('pre_a1_greetings');
      profile = _tracker
          .completePractice(profile, _course,
              [for (final e in lesson.exercises) answer(e.id, true)],
              now: _now)
          .profile;
      final recall =
          profile.reviewItems.singleWhere((i) => i.id == 'lesson-${lesson.id}');
      expect(recall.intervalDays, 3);

      profile = _tracker
          .completePractice(profile, _course,
              [for (final e in lesson.exercises) answer(e.id, false)],
              now: _now)
          .profile;
      expect(
        profile.reviewItems
            .singleWhere((i) => i.id == 'lesson-${lesson.id}')
            .intervalDays,
        0,
      );
    });

    test('retries do not count toward statistics or XP', () {
      final started =
          _tracker.startLesson(_learner(), _lesson('pre_a1_greetings'));
      final first = answer('greeting_1', false);
      final retry = answer('greeting_1', true).asRetry();
      final update = _tracker.completePractice(started, _course, [first, retry],
          now: _now);

      expect(update.xpEarned, 0);
      expect(update.profile.skillStats['greetings']!.attempts, 1);
      expect(update.profile.exerciseStats['greeting_1']!.attempts, 1);
    });
  });

  group('ExerciseSession retry', () {
    test('a missed exercise is asked once more at the end', () {
      final a = _course.exerciseById('greeting_1')!;
      final b = _course.exerciseById('greeting_2')!;
      final session = ExerciseSession([a, b], retryMissed: true);

      session.submit('§wrong§');
      session.advance();
      session.submit(b.answer);
      session.advance();

      expect(session.isFinished, isFalse);
      expect(session.total, 3);
      expect(session.isRetry, isTrue);
      expect(session.current.id, a.id);

      expect(session.submit('§still wrong§').isRetry, isTrue);
      session.advance();
      expect(session.isFinished, isTrue, reason: 'a retry is never repeated');
      expect(session.firstAttemptCount, 2);
      expect(session.correctCount, 1);
    });

    test('without retryMissed nothing is repeated', () {
      final a = _course.exerciseById('greeting_1')!;
      final session = ExerciseSession([a]);
      session.submit('§wrong§');
      session.advance();
      expect(session.isFinished, isTrue);
    });
  });

  group('TutorContextBuilder', () {
    const builder = TutorContextBuilder();

    test('shares vocabulary only from completed lessons, newest first', () {
      var profile = _complete(_learner(), 'pre_a1_greetings');
      profile = _complete(profile, 'pre_a1_numbers');
      final context = builder.build(profile, _course);

      expect(context.knownVocabulary.first, 'eins');
      expect(context.knownVocabulary, contains('Danke'));
      expect(context.knownVocabulary, isNot(contains('heißen')),
          reason: 'introductions was never completed');
      expect(context.knownVocabulary.length,
          lessThanOrEqualTo(TutorContextBuilder.maxVocabulary));
    });

    test('reports weak skills and recent mistakes from real answers', () {
      var profile = _learner(CefrLevel.a1);
      profile = _complete(profile, 'a1_articles',
          wrong: {for (final e in _lesson('a1_articles').exercises) e.id});
      final context =
          builder.build(profile, _course, currentLesson: _lesson('a1_sein'));

      expect(context.weakSkills, ['Definite articles']);
      expect(context.recentMistakes, isNotEmpty);
      expect(context.lesson, 'The verb sein');
      expect(context.unit, 'Daily life');
    });
  });

  test('exercise history survives encoding', () {
    final profile =
        _complete(_learner(), 'pre_a1_greetings', wrong: {'greeting_1'});
    final decoded = ProfileCodec.decode(
      ProfileCodec.encode(profile, encodeDate: (d) => d.toIso8601String()),
      decodeDate: (raw) => DateTime.parse(raw as String),
    );
    expect(decoded.exerciseStats['greeting_1']!.correct, 0);
    expect(decoded.exerciseStats['greeting_2']!.correct, 1);
    expect(decoded.exerciseStats['greeting_1']!.lastAnsweredAt, _now);
  });

  group('AppController', () {
    late InMemoryLearningRepository repository;
    late AppController controller;

    setUp(() async {
      repository = InMemoryLearningRepository();
      controller = AppController(
          learningRepository: repository, aiRepository: MockAIRepository());
      await controller.initialize();
    });

    test('onboarding at A1 begins at the first A1 lesson', () async {
      await controller.completeOnboarding(
          language: 'English', level: CefrLevel.a1);
      expect(controller.currentLesson!.id, 'a1_articles');
      expect(repository.profile!.currentLessonId, 'a1_articles');
    });

    test('changing level moves the recommended lesson', () async {
      await controller.completeOnboarding(
          language: 'English', level: CefrLevel.preA1);
      expect(controller.currentLesson!.id, 'pre_a1_greetings');

      await controller.updateProfile(
          controller.profile!.copyWith(currentLevel: CefrLevel.a2));
      expect(controller.currentLesson!.level, CefrLevel.a2);
    });

    test('a finished lesson unlocks practice and feeds the tutor', () async {
      await controller.completeOnboarding(
          language: 'English', level: CefrLevel.preA1);
      expect(controller.practiceExercises(), isEmpty);

      final lesson = controller.currentLesson!;
      await controller.completeLesson(
          lesson, _answers(lesson, wrong: {'greeting_1'}));

      expect(controller.practiceExercises(), isNotEmpty);
      expect(controller.tutorContext.knownVocabulary, contains('Danke'));
      expect(controller.tutorContext.recentMistakes, isNotEmpty);
      expect(controller.plan, isNotNull);
    });

    test('reset returns to the first lesson of the learner’s level', () async {
      await controller.completeOnboarding(
          language: 'English', level: CefrLevel.a1);
      await controller.completeLesson(
          controller.currentLesson!, _answers(controller.currentLesson!));
      await controller.resetLearningProgress();
      expect(controller.currentLesson!.id, 'a1_articles');
      expect(controller.profile!.lessonProgress, isEmpty);
    });
  });

  test('the scheduler still spaces successful recalls', () {
    const scheduler = ReviewScheduler();
    final item = ReviewItem(id: 'x', label: 'x', kind: 'x', dueAt: _now);
    expect(
        scheduler.schedule(item, ReviewRating.good, now: _now).intervalDays, 3);
  });
}
