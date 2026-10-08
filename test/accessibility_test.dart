import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

LearningProfile _profile() => LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.preA1)
        .copyWith(
      xp: 40,
      streak: 2,
      lastStudyDate: DateTime.now(),
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress(
            status: LessonStatus.completed,
            attempts: 1,
            bestCorrect: 2,
            total: 3),
      },
      skillStats: const {'greetings': SkillStat(attempts: 3, correct: 1)},
    );

const _phone = Size(390, 844);

/// Visits every main destination and runs [check] on each.
Future<void> _eachScreen(
  WidgetTester tester,
  Future<void> Function(String screen) check,
) async {
  for (final label in ['Home', 'Learn', 'Practice', 'Coach']) {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    await check(label);
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('accessibility in ${brightness.name} mode', () {
      testWidgets('tap targets are large enough and every one is labelled',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSprichst(tester,
            size: _phone,
            brightness: brightness,
            repository: InMemoryLearningRepository(_profile()));

        await _eachScreen(tester, (screen) async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
              reason: '$screen: Android 48dp');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline),
              reason: '$screen: iOS 44pt');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
              reason: '$screen: labels');
        });
        handle.dispose();
      });

      testWidgets('rendered text meets contrast guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSprichst(tester,
            size: _phone,
            brightness: brightness,
            repository: InMemoryLearningRepository(_profile()));

        await _eachScreen(tester, (screen) async {
          // The Coach screen holds no learner content, and its text is covered
          // by the palette test; the others are checked as rendered.
          if (screen == 'Coach') return;
          await expectLater(tester, meetsGuideline(textContrastGuideline),
              reason: '$screen: contrast');
        });
        handle.dispose();
      });

      testWidgets('exercise screens are accessible while answering and after',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSprichst(tester,
            size: _phone,
            brightness: brightness,
            repository: InMemoryLearningRepository(_profile()));

        await tester.tap(find.text('Learn').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Greetings').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start practice'));
        await tester.pumpAndSettle();

        // Choose a wrong option, then check it: both states.
        await tester.tap(find.text('Bitte'));
        await tester.pumpAndSettle(); // let the button finish its colour change
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(find.text('Check answer'));
        await tester.pumpAndSettle();
        expect(find.text('Not quite'), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsWidgets,
            reason: 'a wrong pick shows an icon, not only a colour');
        expect(find.byIcon(Icons.check_circle), findsWidgets,
            reason: 'the right answer is also marked with an icon');
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    });
  }

  for (final scale in [1.5, 2.0]) {
    testWidgets('layouts survive ${scale}x system text size', (tester) async {
      await pumpSprichst(tester,
          size: _phone,
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_profile()),
          textScale: scale);

      await _eachScreen(tester, (screen) async {
        expect(tester.takeException(), isNull, reason: '$screen at ${scale}x');
      });
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      for (final label in ['Progress', 'Account']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label at ${scale}x');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Learn').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Greetings').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'exercise at ${scale}x');
    });
  }

  testWidgets('a typed answer can be submitted from the keyboard',
      (tester) async {
    await pumpSprichst(tester,
        size: _phone,
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_profile()));

    // "Introduce yourself" opens with a typed fill-in-the-blank exercise.
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Introduce yourself'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Introduce yourself'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'heiße');
    await tester.pump(); // a real keyboard always yields a frame before Done
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Correct!'), findsOneWidget);
  });
}
