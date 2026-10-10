// Renders the main screens to PNG files so the design can be reviewed without
// a device:
//
//   SHOT_DIR=build/shots flutter test tool/screenshots_test.dart
//
// Uses the real theme, the bundled Roboto and the same seeded learner as the
// widget tests. Not part of the normal test run (it lives in tool/).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import '../test/support/fakes.dart';

final _dir = Platform.environment['SHOT_DIR'] ?? 'build/shots';

Future<void> _loadFonts() async {
  final figtree = FontLoader('Figtree');
  // Text with no font named (button labels, for one) is drawn with the test
  // font, solid blocks. Giving that font's name to Roboto makes it readable.
  for (final file in Directory('assets/fonts/figtree')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf'))) {
    figtree.addFont(Future.value(
        ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
  }
  await figtree.load();
  for (final family in ['Roboto', 'Ahem']) {
    final loader = FontLoader(family);
    for (final file in Directory('assets/fonts/roboto')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ttf'))) {
      loader.addFont(Future.value(
          ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    }
    await loader.load();
  }

  // Material icons come from the Flutter SDK, which tests do not load alone.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/opt/homebrew/Caskroom/flutter/3.24.3/flutter';
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          ByteData.view(Uint8List.fromList(icons.readAsBytesSync()).buffer)));
    await iconLoader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

LearningProfile _learner() => LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(
      name: 'Mord',
      goal: LearningGoal.goethe,
      xp: 340,
      streak: 6,
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress(
            status: LessonStatus.completed,
            attempts: 1,
            bestCorrect: 5,
            total: 6),
      },
    );

void main() {
  setUpAll(_loadFonts);

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final mode = brightness.name;

    testWidgets('sign in and onboarding, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: brightness,
          repository: InMemoryLearningRepository(),
          signedIn: false);
      await _shot(tester, '$mode-auth');
    });

    testWidgets('onboarding, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: brightness,
          repository: InMemoryLearningRepository());
      await _shot(tester, '$mode-onboarding');
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-onboarding-language');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-onboarding-level');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-onboarding-goal');
    });

    testWidgets('study screens, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: brightness,
          repository: InMemoryLearningRepository(_learner()));
      // Exercise.
      await tester.tap(find.text('Open lesson'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-exercise');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Flashcards.
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      final review = find.textContaining(RegExp(r'^Review \d+ cards'));
      await tester.scrollUntilVisible(review, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(review);
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-flashcard');
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-flashcard-answer');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // A game and the mock exam.
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      final game = find.text('Artikel-Rausch');
      await tester.scrollUntilVisible(game, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(game);
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-game');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Practice hub: games and flashcards.
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-practice-2');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-practice-3');
    });

    testWidgets('inner screens, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: brightness,
          repository: InMemoryLearningRepository(_learner()));
      // Lesson.
      await tester.tap(find.text('Open lesson'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-lesson');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // AI & voice, with the Groq section.
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI & voice'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-ai-voice');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-ai-voice-2');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // A legal document.
      await tester.ensureVisible(find.text('Legal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legal'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-legal-hub');
    });
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final mode = brightness.name;
    testWidgets('phone screens, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: brightness,
          repository: InMemoryLearningRepository(_learner()));
      await _shot(tester, '$mode-home');
      for (final tab in ['Learn', 'Practice', 'Coach', 'More']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        await _shot(tester, '$mode-${tab.toLowerCase()}');
      }
      // Screens behind "More".
      await tester.tap(find.text('Progress').first);
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-progress');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account').first);
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-account');
      await tester.ensureVisible(find.text('Legal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legal'));
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-legal');
    });

    testWidgets('tablet screens, $mode', (tester) async {
      await pumpSprichst(tester,
          size: const Size(1100, 800),
          brightness: brightness,
          repository: InMemoryLearningRepository(_learner()));
      await _shot(tester, '$mode-wide-home');
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      await _shot(tester, '$mode-wide-progress');
    });
  }
}
