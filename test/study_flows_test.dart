import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

const _phone = Size(390, 844);

/// Wide enough for the navigation rail, which lists Progress directly.
const _wide = Size(900, 900);

LearningProfile _learner({LearningGoal goal = LearningGoal.everyday}) =>
    LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(
      goal: goal,
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress.started(),
      },
    );

Future<InMemoryLearningRepository> _app(
  WidgetTester tester, {
  LearningGoal goal = LearningGoal.everyday,
  Brightness brightness = Brightness.light,
  Size size = _phone,
}) async {
  final repository = InMemoryLearningRepository(_learner(goal: goal));
  await pumpSprichst(tester,
      size: size, brightness: brightness, repository: repository);
  return repository;
}

/// The "Review N cards" button, not the "Review queue" heading above it.
final _reviewButton = find.textContaining(RegExp(r'^Review \d+ cards'));

final _scroller = find
    .descendant(
        of: find.byType(ListView).first, matching: find.byType(Scrollable))
    .first;

/// Scrolls [target] into view (the lists build lazily) and lets it settle.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, scrollable: _scroller);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding records the chosen goal', (tester) async {
    final repository = InMemoryLearningRepository();
    await pumpSprichst(tester,
        size: _phone, brightness: Brightness.light, repository: repository);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goethe-Zertifikat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Build my learning plan'));
    await tester.tap(find.text('Build my learning plan'));
    await tester.pumpAndSettle();
    expect(repository.profile!.goal, LearningGoal.goethe);
  });

  group('Practice hub', () {
    testWidgets('offers quests, flashcards and all five games', (tester) async {
      await _app(tester);
      await _open(tester, 'Practice');
      expect(find.text('Daily quests'), findsOneWidget);
      await _reveal(tester, find.text('Flashcards'));
      expect(find.text('Flashcards'), findsOneWidget);
      await _reveal(tester, find.text('Gespräch'));
      for (final title in [
        'Artikel-Rausch',
        'Memory',
        'Buchstabensalat',
        'Wortle',
        'Gespräch',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Exam training'), findsNothing);
    });

    testWidgets('an exam goal adds exam training and a mock exam',
        (tester) async {
      await _app(tester, goal: LearningGoal.goethe);
      await _open(tester, 'Practice');
      await _reveal(tester, find.text('Exam training'));
      expect(find.text('Preparing for Goethe-Zertifikat'), findsOneWidget);
      await _reveal(tester, find.text('Take a mock exam'));
      await tester.tap(find.text('Take a mock exam'));
      await tester.pumpAndSettle();
      expect(find.text('Modelltest'), findsOneWidget);
      expect(find.text('Lesen'), findsOneWidget);
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Teil'), findsWidgets);
    });

    testWidgets('flashcards open from the hub', (tester) async {
      await _app(tester);
      await _open(tester, 'Practice');
      await _reveal(tester, _reviewButton);
      await tester.tap(_reviewButton.first);
      await tester.pumpAndSettle();
      expect(find.text('Show answer'), findsOneWidget);
    });

    testWidgets('a game opens from the hub', (tester) async {
      await _app(tester);
      await _open(tester, 'Practice');
      await _reveal(tester, find.text('Wortle'));
      await tester.tap(find.text('Wortle'));
      await tester.pumpAndSettle();
      expect(find.text('Guess the five-letter German word.'), findsOneWidget);
    });
  });

  group('Progress', () {
    testWidgets('shows insights, badges, and exam readiness for exam goals',
        (tester) async {
      await _app(tester, goal: LearningGoal.goethe, size: _wide);
      await _open(tester, 'Progress');
      expect(find.text('How you learn'), findsOneWidget);
      await _reveal(tester, find.text('Goethe-Zertifikat readiness'));
      await _reveal(tester, find.text('Badges'));
      expect(find.text('Badges'), findsOneWidget);
    });
  });

  group('accessibility of the new screens', () {
    for (final brightness in Brightness.values) {
      testWidgets('Practice, Progress and mock exam in ${brightness.name} mode',
          (tester) async {
        final handle = tester.ensureSemantics();
        await _app(tester,
            goal: LearningGoal.goethe, brightness: brightness, size: _wide);
        for (final tab in ['Practice', 'Progress']) {
          await _open(tester, tab);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
              reason: '$tab: Android 48dp');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline),
              reason: '$tab: iOS 44pt');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
              reason: '$tab: labels');
          await expectLater(tester, meetsGuideline(textContrastGuideline),
              reason: '$tab: contrast');
        }
        handle.dispose();
      });

      testWidgets('flashcards and games in ${brightness.name} mode',
          (tester) async {
        final handle = tester.ensureSemantics();
        await _app(tester, brightness: brightness);
        await _open(tester, 'Practice');
        await _reveal(tester, _reviewButton);
        await tester.tap(_reviewButton.first);
        await tester.pumpAndSettle();
        for (var step = 0; step < 2; step++) {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          if (step == 0) {
            await tester.tap(find.text('Show answer'));
            await tester.pumpAndSettle();
          }
        }
        handle.dispose();
      });
    }
  });

  testWidgets('layouts hold at 2x text size', (tester) async {
    final repository =
        InMemoryLearningRepository(_learner(goal: LearningGoal.goethe));
    await pumpSprichst(tester,
        size: _wide,
        brightness: Brightness.light,
        repository: repository,
        textScale: 2);
    for (final tab in ['Practice', 'Progress']) {
      await _open(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
