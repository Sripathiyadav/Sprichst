import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/onboarding/intro_tour.dart';
import 'package:sprichst/shared/widgets/lottie_view.dart';

import 'support/fakes.dart';

Future<void> _next(WidgetTester tester) async {
  final next = find.byKey(const ValueKey('tour-next'));
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _pumpTour(
  WidgetTester tester, {
  required VoidCallback onDone,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: brightness == Brightness.dark
        ? SprichstTheme.dark
        : SprichstTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: IntroTour(onDone: onDone),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the animation files', () {
    final files = Directory('assets/lottie')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('every animation has a light and a dark file', () {
      final names = files.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, isNotEmpty);
      for (final name in names.where((n) => n.endsWith('_light.json'))) {
        expect(names, contains(name.replaceFirst('_light.json', '_dark.json')));
      }
    });

    test('the tour is one animation, in both themes', () {
      for (final brightness in Brightness.values) {
        expect(File(SprichstLottie.assetOf('tour', brightness)).existsSync(),
            isTrue,
            reason: brightness.name);
      }
    });

    test('the tour file has a 3 s scene for each page', () async {
      final composition = await LottieComposition.fromBytes(
          File('assets/lottie/tour_light.json').readAsBytesSync());
      expect(
          composition.duration, const Duration(seconds: 3) * tourPages.length);
    });

    test('every file is a valid Lottie composition that plays for a while',
        () async {
      for (final file in files) {
        final composition =
            await LottieComposition.fromBytes(file.readAsBytesSync());
        expect(composition.duration, greaterThan(Duration.zero),
            reason: file.path);
        expect(composition.bounds.width, greaterThan(0), reason: file.path);
      }
    });
  });

  group('the tour', () {
    testWidgets('one page whose words follow the animation', (tester) async {
      var done = 0;
      await _pumpTour(tester, onDone: () => done++);
      expect(tourPages, hasLength(3));
      expect(find.byType(Lottie), findsOneWidget);
      // pumpAndSettle ran the animation to its end: the last scene's words.
      expect(find.text(tourPages.last.title), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-dot-0')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tourPages.first.title), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(tourPages[1].title), findsOneWidget);
      await tester.pumpAndSettle();
      await _next(tester);
      expect(done, 1);
    });

    testWidgets('Skip leaves at once', (tester) async {
      var done = 0;
      await _pumpTour(tester, onDone: () => done++);
      await tester.tap(find.byKey(const ValueKey('tour-skip')));
      expect(done, 1);
    });

    testWidgets('pictures are hidden from screen readers', (tester) async {
      await _pumpTour(tester, onDone: () {});
      expect(
          find.ancestor(
              of: find.byType(Lottie), matching: find.byType(ExcludeSemantics)),
          findsWidgets);
    });

    testWidgets('reduced motion shows a still picture and every scene’s words',
        (tester) async {
      await _pumpTour(tester, onDone: () {}, reduceMotion: true);
      final lottie = tester.widget<Lottie>(find.byType(Lottie));
      expect(lottie.controller, isA<AlwaysStoppedAnimation<double>>());
      for (final page in tourPages) {
        expect(find.text(page.title), findsOneWidget);
      }
    });

    testWidgets('with motion, the picture plays once and then stops',
        (tester) async {
      await _pumpTour(tester, onDone: () {});
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'fits a small phone in ${brightness.name} mode at ${scale}x text',
            (tester) async {
          await _pumpTour(tester,
              onDone: () {},
              brightness: brightness,
              textScale: scale,
              size: const Size(320, 568));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('in the app', () {
    testWidgets('onboarding opens on the tour, then asks the level',
        (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository());
      expect(find.byType(Lottie), findsOneWidget);
      expect(find.text('Willkommen bei Sprichst.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Where are you now?'), findsOneWidget);
    });

    testWidgets('the tour can be taken again from Account', (tester) async {
      await pumpSprichst(tester,
          size: const Size(1280, 900),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(LearningProfile.newLearner(
              nativeLanguage: 'English', currentLevel: CefrLevel.a1)));
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('How Sprichst works'));
      await tester.tap(find.text('How Sprichst works'));
      await tester.pumpAndSettle();
      expect(find.text('HOW SPRICHST WORKS'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-skip')));
      await tester.pumpAndSettle();
      expect(find.text('HOW SPRICHST WORKS'), findsNothing);
      expect(find.text('How Sprichst works'), findsOneWidget);
    });
  });
}
