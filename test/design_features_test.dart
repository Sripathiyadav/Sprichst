import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/study_time.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/ai_coach/ai_coach_view.dart';

import 'support/fakes.dart';

LearningProfile _learner({CefrLevel level = CefrLevel.a1}) =>
    LearningProfile.newLearner(nativeLanguage: 'English', currentLevel: level)
        .copyWith(name: 'Alex');

Future<void> _pump(WidgetTester tester, LearningProfile profile) async {
  await pumpSprichst(tester,
      size: const Size(390, 844),
      brightness: Brightness.light,
      repository: InMemoryLearningRepository(profile));
}

void main() {
  group('StudyTime', () {
    final friday = DateTime(2026, 10, 30, 18);

    test('adds sessions to their day and reports whole minutes', () {
      final time = const StudyTime()
          .add(const Duration(minutes: 4, seconds: 40), friday)
          .add(const Duration(minutes: 5, seconds: 30), friday);
      expect(time.minutesOn(friday), 10);
      expect(time.minutesOn(friday.subtract(const Duration(days: 1))), 0);
    });

    test('one session counts for at most an hour', () {
      final time = const StudyTime().add(const Duration(hours: 5), friday);
      expect(time.minutesOn(friday), 60);
    });

    test('forgets days older than two weeks', () {
      final old = DateTime(2026, 10, 1, 9);
      final time = const StudyTime()
          .add(const Duration(minutes: 10), old)
          .add(const Duration(minutes: 3), friday);
      expect(time.seconds.keys, isNot(contains('2026-10-01')));
      expect(time.minutesOn(friday), 3);
    });

    test('the week runs Monday to Sunday around today', () {
      final time = const StudyTime()
          .add(const Duration(minutes: 12), DateTime(2026, 10, 26, 8))
          .add(const Duration(minutes: 9), friday)
          .add(const Duration(minutes: 20), DateTime(2026, 10, 25, 8));
      final week = time.week(friday);
      expect(week.first.day, DateTime(2026, 10, 26));
      expect(week.last.day, DateTime(2026, 11, 1));
      expect([for (final d in week) d.minutes], [12, 0, 0, 0, 9, 0, 0]);
      expect(time.weekMinutes(friday), 21);
    });
  });

  group('the controller counts study time', () {
    Future<(AppController, MemoryStudyTimeStore)> start() async {
      final container = ProviderContainer(
          overrides: testOverrides(InMemoryLearningRepository(_learner())));
      addTearDown(container.dispose);
      final store =
          container.read(studyTimeStoreProvider) as MemoryStudyTimeStore;
      final app = container.read(appControllerProvider);
      await app.initialize();
      return (app, store);
    }

    test('a finished lesson adds its time, saved on the device', () async {
      final (app, store) = await start();
      final lesson = app.currentLesson!;
      await app.completeLesson(
        lesson,
        [
          for (final e in lesson.exercises)
            const ExerciseEvaluator().evaluate(e, e.answer)
        ],
        spent: const Duration(minutes: 7),
      );
      final now = DateTime.now();
      expect(app.studyTime.minutesOn(now), 7);
      expect((await store.load()).minutesOn(now), 7);
    });

    test('resetting progress clears the minutes', () async {
      final (app, store) = await start();
      await app.recordStudyTime(const Duration(minutes: 4));
      await app.resetLearningProgress();
      expect(app.studyTime.minutesOn(DateTime.now()), 0);
      expect((await store.load()).seconds, isEmpty);
    });
  });

  testWidgets('Home shows the daily goal and this week’s minutes',
      (tester) async {
    await _pump(tester, _learner());
    expect(find.text('Ready for today’s 15 minutes?'), findsOneWidget);
    await tester.dragUntilVisible(find.byKey(const ValueKey('week-minutes')),
        find.byType(ListView).first, const Offset(0, -300));
    expect(find.text('Minutes learned'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget);
  });

  testWidgets('phones have a Progress tab and no More tab', (tester) async {
    await _pump(tester, _learner());
    expect(find.text('More'), findsNothing);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Your progress'), findsWidgets);
    await tester.dragUntilVisible(find.byKey(const ValueKey('week-minutes')),
        find.byType(ListView).last, const Offset(0, -300));
    expect(find.byKey(const ValueKey('week-minutes')), findsOneWidget);
  });

  testWidgets('Learn opens on the learner’s level and shows another on tap',
      (tester) async {
    await _pump(tester, _learner());
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    final a1 = find.byKey(const ValueKey('level-tab-a1'));
    expect(tester.widget<ChoiceChip>(a1).selected, isTrue);
    expect(find.byKey(const ValueKey('other-level-note')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('level-tab-a2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('other-level-note')), findsOneWidget);
    expect(find.text('You’re on A1'), findsOneWidget);

    await tester.ensureVisible(find.text('Back to A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to A1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('other-level-note')), findsNothing);
  });

  testWidgets('a coach situation starts the conversation', (tester) async {
    await _pump(tester, _learner());
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('OR PICK A SITUATION'), findsOneWidget);
    final cafe = coachSituations.first;
    final chip = find.byKey(ValueKey('situation-${cafe.label}'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text(cafe.opener), findsOneWidget);
    expect(find.text('OR PICK A SITUATION'), findsNothing);
  });
}
