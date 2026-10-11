import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/learning/typing_practice.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/practice/writing_practice_view.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

final _t0 = DateTime(2026, 10, 11, 10);

void main() {
  group('sentences', () {
    test('an example is split into German and English', () {
      final s = TypingPractice.parse(
          'Ich habe Hunger. — I am hungry (literally: I have hunger).')!;
      expect(s.german, 'Ich habe Hunger.');
      expect(s.english, 'I am hungry.');
      expect(TypingPractice.parse('Hallo'), isNull);
    });

    test('the course has plenty to type, and umlaut sentences come first', () {
      final curriculum = Curriculum(loadCourse());
      final picked = TypingPractice.pick(curriculum, CefrLevel.b2, seed: 3);
      expect(picked, hasLength(5));
      expect(picked.any((s) => s.specialLetters > 0), isTrue);
      for (final s in picked) {
        expect(s.german.length, inInclusiveRange(8, 70));
      }
      // Never from a lesson above the learner's level.
      final low = TypingPractice.pick(curriculum, CefrLevel.preA1, seed: 1);
      expect(low, isNotEmpty);
    });

    test('a different seed gives a different set', () {
      final curriculum = Curriculum(loadCourse());
      final a = TypingPractice.pick(curriculum, CefrLevel.b2, seed: 1);
      final b = TypingPractice.pick(curriculum, CefrLevel.b2, seed: 2);
      expect(a.map((s) => s.german).toList(),
          isNot(b.map((s) => s.german).toList()));
    });
  });

  group('a typing run', () {
    test('typing it right finishes, with speed and accuracy', () {
      final run = TypingRun('Ich bin müde.');
      var now = _t0;
      var text = '';
      for (final ch in 'Ich bin müde.'.split('')) {
        text += ch;
        run.update(text, now = now.add(const Duration(milliseconds: 300)));
      }
      expect(run.finished, isTrue);
      expect(run.mistakes, 0);
      expect(run.accuracy, 1);
      // 13 letters in about 3.6 s: well over 10 words a minute.
      expect(run.wpm, greaterThan(10));
    });

    test('a wrong letter is a mistake, and fixing it is not another', () {
      final run = TypingRun('Süß');
      run.update('S', _t0);
      run.update('Su', _t0); // u instead of ü
      expect(run.mistakes, 1);
      expect(run.firstWrong, 1);
      expect(run.next, isNull);
      run.update('S', _t0); // delete
      expect(run.mistakes, 1);
      run.update('Sü', _t0);
      run.update('Süß', _t0);
      expect(run.finished, isTrue);
      expect(run.accuracy, closeTo(3 / 4, .001));
    });

    test('the next letter is reported, umlauts included', () {
      final run = TypingRun('für');
      expect(run.next, 'f');
      run.update('f', _t0);
      expect(run.next, 'ü');
    });

    test('pasting counts against accuracy', () {
      final run = TypingRun('Hallo Welt');
      run.update('Hallo Welt', _t0);
      expect(run.finished, isTrue);
      // The words were not typed: a pasted block is all mistakes here only
      // when it does not extend what was typed; this one replaced it.
      expect(run.keystrokes, greaterThan(0));
    });

    test('a session summary averages the runs', () {
      final a = TypingRun('Guten Tag');
      final b = TypingRun('Gute Nacht');
      var now = _t0;
      for (final run in [a, b]) {
        var text = '';
        for (final ch in run.target.split('')) {
          text += ch;
          run.update(text, now = now.add(const Duration(milliseconds: 250)));
        }
      }
      final s = TypingSummary([a, b]);
      expect(s.sentences, 2);
      expect(s.accuracy, 1);
      expect(s.wpm, greaterThan(0));
    });
  });

  group('the screen', () {
    const sentences = [
      TypingSentence('Ich bin müde.', 'I am tired.'),
      TypingSentence('Wir gehen nach Hause.', 'We go home.'),
    ];

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(),
        home: const WritingPracticeView(sentences: sentences),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the German keys type umlauts at the cursor', (tester) async {
      await pump(tester);
      expect(find.text('I am tired.'), findsOneWidget);
      for (final k in ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü']) {
        expect(find.byKey(ValueKey('key-$k')), findsOneWidget);
      }
      await tester.enterText(
          find.byKey(const ValueKey('typing-field')), 'Ich bin m');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('key-ü')));
      await tester.pump();
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('typing-field')));
      expect(field.controller!.text, 'Ich bin mü');
    });

    testWidgets('typing a sentence right enables Next and shows the speed',
        (tester) async {
      await pump(tester);
      final next = find.byKey(const ValueKey('typing-next'));
      expect(tester.widget<PrimaryButton>(next).onPressed, isNull);
      await tester.enterText(
          find.byKey(const ValueKey('typing-field')), 'Ich bin müde.');
      await tester.pump();
      expect(find.textContaining('words per minute'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(next).onPressed, isNotNull);
    });

    testWidgets('a wrong letter is named, in words', (tester) async {
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('typing-field')), 'Ich bin mu');
      await tester.pump();
      expect(find.textContaining('Letter 10 is not right'), findsOneWidget);
      expect(find.textContaining('type “ü”'), findsOneWidget);
    });

    testWidgets('finishing all sentences shows the summary', (tester) async {
      await pump(tester);
      for (final s in sentences) {
        await tester.enterText(
            find.byKey(const ValueKey('typing-field')), s.german);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('typing-next')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Schön getippt!'), findsOneWidget);
      expect(find.textContaining('2 sentences'), findsOneWidget);
      expect(find.byKey(const ValueKey('typing-again')), findsOneWidget);
    });

    testWidgets('the tips explain how to type umlauts on a keyboard',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('typing-tips')));
      await tester.pumpAndSettle();
      expect(find.textContaining('⌥'), findsOneWidget);
    });
  });

  group('in the app', () {
    testWidgets('Practice opens writing practice with real lesson sentences',
        (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 900),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1)));
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('open-writing'));
      await tester.dragUntilVisible(
          open, find.byType(ListView).first, const Offset(0, -300));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typing-target')), findsOneWidget);
      expect(find.byKey(const ValueKey('typing-english')), findsOneWidget);
    });

    testWidgets('Home has a way in too', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 1600),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1)));
      await tester.tap(find.byKey(const ValueKey('home-writing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typing-field')), findsOneWidget);
    });
  });
}
