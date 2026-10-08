import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/learning/adaptive_planner.dart';
import 'package:sprichst/domain/learning/exam_readiness.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/learner_insights.dart';
import 'package:sprichst/domain/learning/learning_path.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/learning/speech_matcher.dart';
import 'package:sprichst/domain/learning/writing_assessor.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

final _course = Curriculum(loadCourse());
const _path = LearningPath();
const _tracker = ProgressTracker();
const _evaluator = ExerciseEvaluator();
final _now = DateTime(2026, 10, 7, 9);

LearningProfile _learner({
  CefrLevel level = CefrLevel.a1,
  LearningGoal goal = LearningGoal.everyday,
}) =>
    LearningProfile.newLearner(nativeLanguage: 'English', currentLevel: level)
        .copyWith(goal: goal);

Lesson _lesson(String id) => _course.lessonById(id)!;

List<ExerciseResult> _answers(Lesson lesson, {bool correct = true}) => [
      for (final e in lesson.exercises)
        _evaluator.evaluate(
          e,
          correct
              ? (e.kind == ExerciseKind.cloze
                  ? e.gaps.map((g) => g.answer).join('|')
                  : e.answer)
              : '§wrong§',
        ),
    ];

LearningProfile _complete(LearningProfile p, String id,
        {bool correct = true}) =>
    _tracker
        .completeLesson(
            p, _lesson(id), _course, _answers(_lesson(id), correct: correct),
            now: _now)
        .profile;

void main() {
  group('goal-aware path', () {
    test('a travel learner is steered to food and ordering once it is unlocked',
        () {
      final profile =
          _complete(_learner(goal: LearningGoal.travel), 'a1_articles');
      final choice = _path.choose(profile, _course)!;
      expect(choice.lesson.id, 'a1_food_ordering');
      expect(choice.reasons.join(' '), contains('Travel'));
    });

    test(
        'an exam learner is offered Goethe preparation; an everyday learner is not',
        () {
      final goethe = _learner(goal: LearningGoal.goethe);
      expect(_path.choose(goethe, _course)!.lesson.exam, 'goethe');

      var everyday = _learner();
      // Work through everything, always taking the recommendation.
      for (var i = 0; i < 40; i++) {
        final next = _path.choose(everyday, _course)!.lesson;
        if (everyday.currentLevel != CefrLevel.a1) break;
        expect(next.exam, isNull,
            reason: 'everyday learner was offered ${next.id}');
        everyday = _complete(everyday, next.id);
      }
    });

    test('prerequisites always hold', () {
      // Food needs articles; with nothing done it must not be offered.
      final profile = _learner(goal: LearningGoal.travel);
      expect(
          _path.choose(profile, _course)!.lesson.id, isNot('a1_food_ordering'));
    });

    test('levels the learner skipped do not block lessons that depend on them',
        () {
      // An A1 learner never did pre_a1_numbers, yet time_dates requires it.
      var profile = _learner();
      for (final l in _course.lessonsAt(CefrLevel.a1)) {
        if (l.id == 'a1_time_dates' || !_path.isRelevant(l, profile.goal)) {
          continue;
        }
        profile = _complete(profile, l.id);
      }
      expect(profile.isLessonCompleted('pre_a1_numbers'), isFalse);
      expect(_path.choose(profile, _course)!.lesson.id, 'a1_time_dates');
    });

    test(
        'a weak skill pulls the lesson that trains it forward, with the reason',
        () {
      // Only "Time and days" trains telling_time, and it is not first in line.
      final base = _complete(_learner(), 'a1_articles');
      expect(_path.choose(base, _course)!.lesson.id, isNot('a1_time_dates'));

      final struggling = base.copyWith(skillStats: {
        'telling_time': const SkillStat(attempts: 4, correct: 1),
      });
      expect(ProgressTracker.weakSkillsOf(struggling), ['telling_time']);
      final choice = _path.choose(struggling, _course)!;
      expect(choice.lesson.id, 'a1_time_dates');
      expect(choice.reasons.join(' '), contains('telling time'));
    });

    test('choosing is deterministic', () {
      final profile = _learner(goal: LearningGoal.work);
      expect(_path.choose(profile, _course)!.lesson.id,
          _path.choose(profile, _course)!.lesson.id);
    });

    test('the plan card carries the personal reason', () {
      final plan = const AdaptivePlanner()
          .plan(_learner(goal: LearningGoal.goethe), _course, now: _now)!;
      expect(plan.kind, PlanKind.lesson);
      expect(plan.reason, contains('Goethe'));
    });
  });

  group('LearnerInsights', () {
    LearningProfile withStats(Map<ExerciseKind, SkillStat> stats) =>
        _learner().copyWith(kindStats: {
          for (final e in stats.entries) e.key.name: e.value,
        });

    test('says it is still learning until there is enough evidence', () {
      final insights = LearnerInsights.build(_learner());
      expect(insights.single.kind, InsightKind.learning);
    });

    test('detects recognising more than producing, and does not before that',
        () {
      final gap = withStats({
        ExerciseKind.multipleChoice: const SkillStat(attempts: 12, correct: 11),
        ExerciseKind.fillBlank: const SkillStat(attempts: 8, correct: 3),
      });
      expect(LearnerInsights.hasProductionGap(gap), isTrue);
      expect(LearnerInsights.build(gap).map((i) => i.kind),
          contains(InsightKind.productionGap));

      final even = withStats({
        ExerciseKind.multipleChoice: const SkillStat(attempts: 12, correct: 10),
        ExerciseKind.fillBlank: const SkillStat(attempts: 8, correct: 6),
      });
      expect(LearnerInsights.hasProductionGap(even), isFalse);

      final tooLittle = withStats({
        ExerciseKind.multipleChoice: const SkillStat(attempts: 3, correct: 3),
        ExerciseKind.fillBlank: const SkillStat(attempts: 1, correct: 0),
      });
      expect(LearnerInsights.hasProductionGap(tooLittle), isFalse);
    });

    test('names the weakest and the strongest mode', () {
      final profile = withStats({
        ExerciseKind.listening: const SkillStat(attempts: 8, correct: 2),
        ExerciseKind.multipleChoice: const SkillStat(attempts: 12, correct: 12),
      });
      final kinds = LearnerInsights.build(profile, limit: 5);
      expect(kinds.map((i) => i.kind),
          containsAll([InsightKind.weakestMode, InsightKind.strength]));
      expect(kinds.firstWhere((i) => i.kind == InsightKind.weakestMode).title,
          contains('Listening'));
    });

    test(
        'practice need rises for weak modes and for production when there is a gap',
        () {
      final gap = withStats({
        ExerciseKind.multipleChoice: const SkillStat(attempts: 12, correct: 11),
        ExerciseKind.fillBlank: const SkillStat(attempts: 8, correct: 3),
      });
      expect(LearnerInsights.need(gap, ExerciseKind.fillBlank),
          greaterThan(LearnerInsights.need(gap, ExerciseKind.multipleChoice)));
      expect(LearnerInsights.need(_learner(), ExerciseKind.writing), 0);
    });

    test('the tracker feeds the per-mode record', () {
      final profile = _complete(_learner(), 'a1_articles');
      expect(profile.kindStats['multipleChoice']!.attempts, greaterThan(0));
      expect(profile.kindStats['fillBlank']!.attempts, greaterThan(0));
      expect(profile.areaStats['grammar']!.attempts, greaterThan(0));
    });
  });

  group('WritingAssessor', () {
    const assessor = WritingAssessor();
    final brief = _lesson('a1_goethe_messages').exercises.first.brief!;

    test('credits content points, form and length', () {
      final good = _lesson('a1_goethe_messages').exercises.first.answer;
      final result = assessor.assess(good, brief);
      expect(result.pointsCovered, [true, true, true]);
      expect(result.hasGreeting, isTrue);
      expect(result.hasClosing, isTrue);
      expect(result.registerConsistent, isTrue);
      expect(result.score, greaterThan(.9));
    });

    test('reports exactly what is missing', () {
      final result = assessor.assess('Hallo Lena, alles Gute!', brief);
      expect(result.pointsCovered, [true, false, false]);
      expect(result.notes.join(' '),
          contains('Add: Say you will come on Saturday'));
      expect(result.notes.join(' '), contains('at least 25 words'));
      expect(result.notes.join(' '), contains('closing'));
      expect(result.score, lessThan(WritingAssessor.passMark));
    });

    test('flags the wrong register in both directions', () {
      final informal = brief;
      final stiff = assessor.assess(
          'Liebe Lena, ich gratuliere Ihnen zum Geburtstag. Ich komme am Samstag. '
          'Was soll ich mitbringen? Mit freundlichen Grüßen, Sam',
          informal);
      expect(stiff.registerConsistent, isFalse);

      final formal = _lesson('a1_goethe_messages').exercises[1].brief!;
      final casual = assessor.assess(
          'Hallo Dr. Berger, ich bin krank. Hast du einen Termin? Ich habe am Montag Zeit. '
          'Viele Grüße',
          formal);
      expect(casual.registerConsistent, isFalse);
      expect(casual.hasGreeting, isFalse);
    });

    test(
        'a sentence-initial "Sie" meaning she/they is not read as formal address',
        () {
      final result = assessor.assess(
          'Liebe Lena, deine Schwester kommt auch. Sie bringt Kuchen mit. '
          'Ich komme am Samstag zur Party und gratuliere dir zum Geburtstag. Viele Grüße',
          brief);
      expect(result.registerConsistent, isTrue);
    });

    test('essays are judged on connected argument, not on letter form', () {
      final essay = _lesson('b1_opinions_connectors').exercises.last;
      final good = assessor.assess(essay.answer, essay.brief!);
      expect(good.connectorCount, greaterThanOrEqualTo(3));
      final choppy = assessor.assess(
          'Homeoffice ist gut. Man spart Zeit. Man ist allein. Das ist ein Nachteil. '
          'Ich finde es gut. Ein Vorteil ist die Zeit.',
          essay.brief!);
      expect(choppy.score, lessThan(good.score));
    });
  });

  group('ExerciseEvaluator exam types', () {
    test('cloze gives partial credit and names the wrong gaps', () {
      final cloze = _lesson('a1_goethe_forms').exercises.first;
      final result = _evaluator.evaluate(cloze, 'Mehmet Yilmaz|72|Köln|Türkei');
      expect(result.isCorrect, isFalse);
      expect(result.score, .75);
      expect(result.feedback, contains('3 of 4 gaps'));
      expect(result.feedback, contains('(2) 27'));
    });

    test('speaking accepts what a recogniser would plausibly return', () {
      final speaking = _lesson('a1_goethe_speaking').exercises.first;
      for (final heard in [
        'ich heiße anna und ich komme aus indien',
        'Ich heisse Anna und ich komme aus Indien.',
        'Mein Name ist Anna und ich komme aus Indien',
      ]) {
        expect(_evaluator.evaluate(speaking, heard).isCorrect, isTrue,
            reason: heard);
      }
      final wrong = _evaluator.evaluate(speaking, 'Wie spät ist es');
      expect(wrong.isCorrect, isFalse);
      expect(wrong.feedback, contains('I heard'));
    });

    test('speech matching is symmetric and bounded', () {
      const matcher = SpeechMatcher();
      expect(matcher.similarity('Grüße', 'Gruesse'), 1);
      expect(matcher.similarity('', ''), 1);
      expect(matcher.similarity('abc', ''), 0);
      expect(matcher.similarity('guten morgen', 'guten abend'),
          closeTo(matcher.similarity('guten abend', 'guten morgen'), 1e-9));
    });

    test('writing and listening plug into the same evaluator', () {
      final writing = _lesson('a1_goethe_messages').exercises.first;
      expect(_evaluator.evaluate(writing, writing.answer).isCorrect, isTrue);
      expect(_evaluator.evaluate(writing, 'Hallo.').feedback,
          contains('Model answer'));
      final listening = _lesson('a1_goethe_listening').exercises.first;
      expect(
          _evaluator.evaluate(listening, listening.answer).isCorrect, isTrue);
    });
  });

  group('exam readiness and mock exam', () {
    test('readiness needs evidence before it says anything', () {
      final readiness = ExamReadiness.of(_learner(goal: LearningGoal.goethe));
      expect(readiness.pillars.map((p) => p.module),
          ['Lesen', 'Hören', 'Schreiben', 'Sprechen']);
      expect(
          readiness.pillars
              .every((p) => p.status == ReadinessStatus.notStarted),
          isTrue);
      expect(readiness.weakest, isNull);
    });

    test('readiness turns on track at the 60% line with enough answers', () {
      final profile = _learner(goal: LearningGoal.goethe).copyWith(areaStats: {
        'reading': const SkillStat(attempts: 20, correct: 17),
        'listening': const SkillStat(attempts: 20, correct: 6),
        'writing': const SkillStat(attempts: 3, correct: 3),
      });
      final readiness = ExamReadiness.of(profile);
      PillarReadiness byName(String m) =>
          readiness.pillars.firstWhere((p) => p.module == m);
      expect(byName('Lesen').status, ReadinessStatus.onTrack);
      expect(byName('Hören').status, ReadinessStatus.building);
      expect(byName('Schreiben').status, ReadinessStatus.notStarted);
      expect(readiness.weakest!.module, 'Hören');
      expect(readiness.onTrack, isFalse);
    });

    test('a mock exam covers all four modules at the learner\'s level', () {
      final profile = _learner(level: CefrLevel.a1, goal: LearningGoal.goethe);
      final exam = MockExam.build(profile, _course);
      expect(exam.sections.map((s) => s.module),
          ['Lesen', 'Hören', 'Schreiben', 'Sprechen']);
      for (final exercise in exam.exercises) {
        expect(exercise.examPart, isNotNull);
        final lesson = _course.lessonOfExercise(exercise.id)!;
        expect(lesson.level.index, lessThanOrEqualTo(CefrLevel.a1.index));
        expect(lesson.exam, 'goethe');
      }
    });

    test('a mock exam prefers tasks not yet tried, and is deterministic', () {
      final fresh = _learner(level: CefrLevel.a1, goal: LearningGoal.goethe);
      final first =
          MockExam.build(fresh, _course).exercises.map((e) => e.id).toList();
      expect(MockExam.build(fresh, _course).exercises.map((e) => e.id).toList(),
          first);

      final tried = fresh.copyWith(exerciseStats: {
        for (final id in first)
          id: ExerciseStat(attempts: 1, correct: 1, lastAnsweredAt: _now),
      });
      final second =
          MockExam.build(tried, _course).exercises.map((e) => e.id).toSet();
      expect(second.intersection(first.toSet()).length, lessThan(first.length));
    });

    test(
        'the report passes a module at 60% and all modules only if each passes',
        () {
      final profile = _learner(level: CefrLevel.a1, goal: LearningGoal.goethe);
      final exam = MockExam.build(profile, _course);
      final perfect = [
        for (final e in exam.exercises)
          _evaluator.evaluate(
              e,
              e.kind == ExerciseKind.cloze
                  ? e.gaps.map((g) => g.answer).join('|')
                  : e.answer),
      ];
      final good = ExamReport.from(exam, perfect);
      expect(good.passedAll, isTrue);
      expect(good.overall, greaterThan(.9));

      final mixed = [
        for (final r in perfect)
          r.exercise.area == SkillArea.listening
              ? _evaluator.evaluate(r.exercise, '§wrong§')
              : r,
      ];
      final report = ExamReport.from(exam, mixed);
      expect(report.passedAll, isFalse);
      expect(report.sections.firstWhere((s) => s.module == 'Hören').passed,
          isFalse);
      expect(report.sections.firstWhere((s) => s.module == 'Lesen').passed,
          isTrue);
    });
  });
}
