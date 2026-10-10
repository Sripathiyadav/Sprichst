import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/games/core_vocabulary.dart';
import 'package:sprichst/domain/games/game_models.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/flashcards/flashcard_session_view.dart';
import 'package:sprichst/features/games/dialogue_game_view.dart';
import 'package:sprichst/features/games/game_page.dart';
import 'package:sprichst/features/games/memory_match_view.dart';
import 'package:sprichst/features/games/word_scramble_view.dart';
import 'package:sprichst/features/games/wortle_view.dart';
import 'package:sprichst/features/games/article_swipe_view.dart';
import 'package:sprichst/features/learn/exercises/exercise_widgets.dart';

import 'support/fakes.dart';

const _phone = Size(390, 844);

LearningProfile _learner({LearningGoal goal = LearningGoal.everyday}) =>
    LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.preA1)
        .copyWith(
      goal: goal,
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress.started(),
      },
    );

/// Pumps [child] on its own, with providers, a phone-sized view and a theme.
Future<InMemoryLearningRepository> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  LearningProfile? profile,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (_) async => null,
  );
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final repository = InMemoryLearningRepository(profile ?? _learner());
  await tester.pumpWidget(ProviderScope(
    overrides: testOverrides(repository),
    child: Consumer(builder: (context, ref, _) {
      return MaterialApp(
        theme: brightness == Brightness.light
            ? SprichstTheme.light
            : SprichstTheme.dark,
        home: child,
      );
    }),
  ));
  await tester.pumpAndSettle();
  // The screens save through the app controller, as they do in the app.
  final container =
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  await tester
      .runAsync(() => container.read(appControllerProvider).initialize());
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  gameAccessibility();

  group('exam task inputs', () {
    Exercise cloze() => const Exercise(
          id: 'c',
          kind: ExerciseKind.cloze,
          prompt: 'Complete the form',
          context: 'Name: {1}\nAlter: {2}',
          gaps: [
            ClozeGap(options: ['Mia', 'Ben'], answer: 'Mia'),
            ClozeGap(options: ['27', '72'], answer: '27'),
          ],
          answer: 'Name: Mia, Alter: 27',
          explanation: 'Facts.',
          skills: ['forms'],
        );

    testWidgets('cloze reports a response only when every gap is filled',
        (tester) async {
      String? response = 'unset';
      await _pump(
        tester,
        Scaffold(
          body: ExerciseRenderer(
            exercise: cloze(),
            onResponse: (r) => response = r,
          ),
        ),
      );
      await tester.tap(find.text('Mia'));
      await tester.pump();
      expect(response, isNull); // second gap still open
      await tester.tap(find.text('27'));
      await tester.pump();
      expect(response, 'Mia|27');
      expect(const ExerciseEvaluator().evaluate(cloze(), response!).isCorrect,
          isTrue);
    });

    testWidgets('writing shows a live word count and ticks content points',
        (tester) async {
      final exercise = loadCourse()
          .expand((l) => l.exercises)
          .firstWhere((e) => e.kind == ExerciseKind.writing);
      String? response;
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ExerciseRenderer(
              exercise: exercise,
              onResponse: (r) => response = r,
            ),
          ),
        ),
      );
      expect(find.textContaining('0 / ${exercise.brief!.minWords} words'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), exercise.answer);
      await tester.pump();
      expect(response, exercise.answer);
      final count = exercise.answer.trim().split(RegExp(r'\s+')).length;
      expect(find.textContaining('$count / ${exercise.brief!.minWords} words'),
          findsOneWidget);
      // The model answer covers every point, so every row ends up ticked.
      expect(find.byIcon(Icons.check_circle),
          findsAtLeastNWidgets(exercise.brief!.points.length));
    });

    testWidgets('listening offers audio and a transcript on demand',
        (tester) async {
      final exercise = loadCourse()
          .expand((l) => l.exercises)
          .firstWhere((e) => e.kind == ExerciseKind.listening);
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ExerciseRenderer(
              exercise: exercise,
              onResponse: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Play audio'), findsOneWidget);
      expect(find.text(exercise.audioText!), findsNothing);
      await tester.tap(find.text('Show transcript'));
      await tester.pump();
      expect(find.text(exercise.audioText!), findsOneWidget);
    });

    testWidgets('speaking can be answered by typing instead', (tester) async {
      final exercise = loadCourse()
          .expand((l) => l.exercises)
          .firstWhere((e) => e.kind == ExerciseKind.speaking);
      String? response;
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ExerciseRenderer(
              exercise: exercise,
              onResponse: (r) => response = r,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), exercise.answer);
      await tester.pump();
      expect(response, exercise.answer);
    });
  });

  group('flashcard session', () {
    testWidgets('flip, rate, finish and save', (tester) async {
      final course = loadCourse();
      final profile = _learner();
      final repository = await _pump(
        tester,
        FlashcardSessionView(
          cards: [
            for (final w in course.first.vocabulary.take(2)) DeckCard(w, null),
          ],
        ),
        profile: profile,
      );
      // The app controller must be initialised to save; mimic the real app by
      // letting the view call it through the provider.
      expect(find.text('WHAT DOES IT MEAN?'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(find.text('Good'), findsOneWidget);
      expect(find.textContaining('1 day'), findsWidgets);
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();
      expect(find.text('Card 2 of 2'), findsOneWidget);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      expect(find.text('Session complete'), findsOneWidget);
      expect(repository.profile!.flashcards.states.length, 2);
    });

    testWidgets('a forgotten card comes round again', (tester) async {
      final word = loadCourse().first.vocabulary.first;
      await _pump(tester, FlashcardSessionView(cards: [DeckCard(word, null)]));
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();
      expect(find.text('Card 2 of 2'), findsOneWidget);
    });

    testWidgets('keyboard: Space reveals, digits rate', (tester) async {
      final word = loadCourse().first.vocabulary.first;
      await _pump(tester, FlashcardSessionView(cards: [DeckCard(word, null)]));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Easy'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(find.text('Session complete'), findsOneWidget);
    });
  });

  group('games', () {
    testWidgets('Artikel-Rausch plays through and saves a result',
        (tester) async {
      final repository = await _pump(
        tester,
        GamePage(
          game: GameId.articleSwipe,
          builder: (_, done) => ArticleSwipeView(
            nouns: coreNouns,
            onFinished: done,
            random: math.Random(1),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.widgetWithText(FilledButton, 'der'));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      await tester.pumpAndSettle();
      expect(find.text('Play again'), findsOneWidget);
      expect(repository.profile!.gamification.gamesPlayed, 1);
    });

    testWidgets('Memory flips tiles and turns a mismatch back', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: MemoryMatchView(
            words: coreNouns,
            onFinished: (_) {},
            random: math.Random(3),
          ),
        ),
      );
      expect(find.text('Pairs 0 / 6'), findsOneWidget);
      final tiles = find.byIcon(Icons.help_outline_rounded);
      expect(tiles, findsNWidgets(12));
      await tester.tap(tiles.at(0));
      await tester.pump();
      await tester.tap(tiles.at(1));
      await tester.pump();
      final shown = 12 -
          tester.widgetList(find.byIcon(Icons.help_outline_rounded)).length;
      expect(shown, anyOf(2, 0)); // two face up, or none if they were a pair
      await tester.pump(const Duration(milliseconds: 1100));
      final matchedOrHidden =
          tester.widgetList(find.byIcon(Icons.help_outline_rounded)).length;
      expect(matchedOrHidden, anyOf(12, 10));
    });

    testWidgets('Buchstabensalat builds the word from tapped letters',
        (tester) async {
      GameOutcome? outcome;
      await _pump(
        tester,
        Scaffold(
          body: WordScrambleView(
            words: [coreNouns.firstWhere((w) => w.german == 'Tisch')],
            onFinished: (o) => outcome = o,
            random: math.Random(2),
          ),
        ),
      );
      for (final letter in 'TISCH'.split('')) {
        await tester.tap(find
            .descendant(
                of: find.byType(GestureDetector), matching: find.text(letter))
            .first);
        await tester.pump();
      }
      expect(outcome, isNotNull);
      expect(outcome!.correct, 1);
    });

    testWidgets('Wortle accepts typed guesses and ends on the answer',
        (tester) async {
      GameOutcome? outcome;
      await _pump(
        tester,
        Scaffold(
          body: WortleView(answer: 'TISCH', onFinished: (o) => outcome = o),
        ),
      );
      Future<void> tapKey(String letter) async {
        await tester.tap(find
            .descendant(
                of: find.byType(GestureDetector), matching: find.text(letter))
            .first);
        await tester.pump();
      }

      await tapKey('L');
      await tapKey('A');
      await tester.tap(find.text('Enter'));
      await tester.pump();
      expect(find.text('Five letters, please.'), findsOneWidget);
      for (final l in 'MPE'.split('')) {
        await tapKey(l);
      }
      await tester.tap(find.text('Enter'));
      await tester.pump();
      for (final l in 'TISCH'.split('')) {
        await tapKey(l);
      }
      await tester.tap(find.text('Enter'));
      await tester.pump(const Duration(seconds: 1));
      expect(outcome, isNotNull);
      expect(outcome!.correct, 1);
      expect(outcome!.stars, 3);
    });

    testWidgets('Wortle uses a text field when a screen reader is on',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      GameOutcome? outcome;
      await _pump(
        tester,
        Scaffold(
          body: WortleView(answer: 'TISCH', onFinished: (o) => outcome = o),
        ),
      );
      expect(find.text('Enter'), findsNothing); // no tiny keys
      await tester.enterText(find.byType(TextField), 'tisch');
      await tester.tap(find.text('Submit guess'));
      await tester.pump(const Duration(seconds: 1));
      expect(outcome, isNotNull);
      expect(outcome!.correct, 1);
    });

    testWidgets('Gespräch runs a dialogue and scores the replies',
        (tester) async {
      GameOutcome? outcome;
      final dialogue = loadCourseDialogues().first;
      await _pump(
        tester,
        Scaffold(
          body: DialogueGameView(
            dialogue: dialogue,
            onFinished: (o) => outcome = o,
            random: math.Random(4),
          ),
        ),
      );
      for (final turn in dialogue.turns.where((t) => t.isLearner)) {
        await tester.tap(find.widgetWithText(OutlinedButton, turn.answer!));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(outcome, isNotNull);
      expect(outcome!.stars, 3);
    });
  });
}

void gameAccessibility() {
  for (final brightness in Brightness.values) {
    group('game screens are accessible in ${brightness.name} mode', () {
      Future<void> check(WidgetTester tester, String screen) async {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
            reason: '$screen: Android 48dp');
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline),
            reason: '$screen: iOS 44pt');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
            reason: '$screen: labels');
        await expectLater(tester, meetsGuideline(textContrastGuideline),
            reason: '$screen: contrast');
      }

      testWidgets('Artikel-Rausch', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
            tester,
            GamePage(
              game: GameId.articleSwipe,
              builder: (_, done) =>
                  ArticleSwipeView(nouns: coreNouns, onFinished: done),
            ),
            brightness: brightness);
        await check(tester, 'article swipe');
        handle.dispose();
      });

      testWidgets('Memory', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
            tester,
            Scaffold(
                body: MemoryMatchView(words: coreNouns, onFinished: (_) {})),
            brightness: brightness);
        await check(tester, 'memory');
        handle.dispose();
      });

      testWidgets('Buchstabensalat', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
            tester,
            Scaffold(
                body: WordScrambleView(words: coreNouns, onFinished: (_) {})),
            brightness: brightness);
        await check(tester, 'scramble');
        handle.dispose();
      });

      testWidgets('Wortle (screen reader input)', (tester) async {
        final handle = tester.ensureSemantics();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await _pump(tester,
            Scaffold(body: WortleView(answer: 'TISCH', onFinished: (_) {})),
            brightness: brightness);
        await check(tester, 'wortle');
        handle.dispose();
      });

      testWidgets('Gespräch', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
            tester,
            Scaffold(
                body: DialogueGameView(
                    dialogue: loadCourseDialogues().first, onFinished: (_) {})),
            brightness: brightness);
        await check(tester, 'dialogue');
        handle.dispose();
      });
    });
  }
}
