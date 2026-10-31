// Renders the Google Play phone screenshots (1080 x 1920, 9:16):
//
//   flutter test tool/playstore_shots_test.dart
//
// Files go to store/play/phone/. Same seeded learner and fonts as the other
// screenshot tool.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import '../test/support/fakes.dart';
import 'shot_support.dart';

const _dir = 'store/play/phone';
var _n = 0;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final image =
        await boundary.toImage(pixelRatio: 3); // 360 x 640 -> 1080 x 1920
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/${(++_n).toString().padLeft(2, '0')}-$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

LearningProfile _learner() => LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(
      name: 'Sam',
      goal: LearningGoal.everyday,
      xp: 340,
      streak: 6,
      lastStudyDate: DateTime.now(),
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress(
            status: LessonStatus.completed,
            attempts: 1,
            bestCorrect: 5,
            total: 6),
      },
    );

Future<void> _open(WidgetTester tester, Brightness b) => pumpSprichst(tester,
    size: const Size(360, 640),
    brightness: b,
    repository: InMemoryLearningRepository(_learner()));

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadShotFonts);

  testWidgets('play store screenshots', (tester) async {
    await _open(tester, Brightness.light);
    await _shot(tester, 'home');
    await _scroll(tester, 520);
    await _shot(tester, 'home-lesson');

    // The lesson and its first exercise.
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await _shot(tester, 'exercise');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    await _shot(tester, 'learn');

    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await _shot(tester, 'practice');

    // The coach, with one exchange.
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ich habe Hunger.');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'coach');

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    await _shot(tester, 'progress');
  });

  testWidgets('play store screenshots, dark', (tester) async {
    await _open(tester, Brightness.dark);
    await _shot(tester, 'home-dark');
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    await _shot(tester, 'learn-dark');
  });
}
