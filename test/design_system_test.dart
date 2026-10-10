import 'dart:io';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

Widget _host(Widget child,
        {Brightness brightness = Brightness.light,
        bool reduceMotion = false,
        double textScale = 1}) =>
    MaterialApp(
      theme: SprichstTheme.build(brightness),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('type', () {
    test('Figtree is bundled, and Roboto stays as the fallback', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Figtree'));
      for (final weight in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
        expect(File('assets/fonts/figtree/Figtree-$weight.ttf').existsSync(),
            isTrue,
            reason: weight);
      }
      expect(File('assets/fonts/figtree/OFL.txt').existsSync(), isTrue);
      expect(SprichstTheme.fontFallback, contains('Roboto'));
    });

    test('every style the buttons and list tiles take carries the family', () {
      // Buttons and tiles use these styles directly, not the merged theme, so
      // a missing family would draw them in the system font.
      final theme = SprichstTheme.light;
      final styles = [
        theme.filledButtonTheme.style!.textStyle!.resolve({}),
        theme.textButtonTheme.style!.textStyle!.resolve({}),
        theme.listTileTheme.subtitleTextStyle,
        theme.listTileTheme.titleTextStyle,
        theme.textTheme.labelLarge,
        theme.textTheme.displayLarge,
      ];
      for (final style in styles) {
        expect(style!.fontFamily, SprichstTheme.fontFamily);
      }
    });

    test('numerals use tabular figures so counts do not jitter', () {
      final features =
          SprichstTheme.light.textTheme.displayLarge!.fontFeatures!;
      expect(features.map((f) => f.feature), contains('tnum'));
    });

    test('the type scale follows the design system', () {
      final t = SprichstTheme.light.textTheme;
      expect((t.displayLarge!.fontSize, t.displayLarge!.fontWeight),
          (120.0, FontWeight.w300));
      expect((t.displaySmall!.fontSize, t.displaySmall!.fontWeight),
          (40.0, FontWeight.w500));
      expect((t.headlineSmall!.fontSize, t.bodyLarge!.fontSize), (24.0, 18.0));
      expect((t.bodyMedium!.fontSize, t.bodySmall!.fontSize), (16.0, 13.0));
      expect(t.labelSmall!.letterSpacing, closeTo(1.04, .001));
    });
  });

  group('EditorialNumber', () {
    testWidgets('pads to two digits, and says what it counts', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
          const EditorialNumber(value: 7, label: 'Day streak', unit: 'days')));
      expect(find.text('07'), findsOneWidget);
      expect(find.text('DAY STREAK'), findsOneWidget);
      expect(tester.getSemantics(find.byType(EditorialNumber)).label,
          '7 days day streak');
      handle.dispose();
    });

    testWidgets('the disc is decoration and carries no semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester
          .pumpWidget(_host(const EditorialNumber(value: 12, disc: true)));
      expect(find.byType(Geometry), findsNWidgets(2)); // disc and ring
      final node = tester.getSemantics(find.byType(EditorialNumber));
      expect(node.label, '12');
      handle.dispose();
    });
  });

  group('FeaturePanel', () {
    testWidgets('has a header, a labelled action, and a tappable arrow',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(FeaturePanel(
        eyebrow: 'Lesson 08 · A1',
        title: 'Ordering food',
        meta: '14 min',
        actionLabel: 'Continue',
        onAction: () => taps++,
        children: const [Text('Order a coffee.')],
      )));
      expect(find.text('LESSON 08 · A1'), findsOneWidget);
      expect(find.text('Ordering food'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
    });

    testWidgets('the hatch can be dropped', (tester) async {
      await tester.pumpWidget(
          _host(const FeaturePanel(title: 'Im Café', hatch: false)));
      expect(find.byType(Geometry), findsNothing);
      await tester.pumpWidget(_host(const FeaturePanel(title: 'Im Café')));
      expect(find.byType(Geometry), findsOneWidget);
    });
  });

  group('OptionTile', () {
    Future<void> pump(WidgetTester tester, OptionState state) =>
        tester.pumpWidget(_host(OptionTile(
            label: 'Tschüss', marker: 'B', state: state, onTap: () {})));

    testWidgets('correct and incorrect each show an icon and a word',
        (tester) async {
      await pump(tester, OptionState.correct);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await pump(tester, OptionState.incorrect);
      expect(find.text('Not this one'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('selected says so; idle says nothing', (tester) async {
      await pump(tester, OptionState.selected);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await pump(tester, OptionState.idle);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('Correct'), findsNothing);
    });

    testWidgets('behaves as a radio group member for assistive technology',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, OptionState.selected);
      final node = tester.getSemantics(find.byType(OptionTile));
      expect(node.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);
      expect(node.hasFlag(SemanticsFlag.isChecked), isTrue);
      expect(node.label, contains('Tschüss'));
      handle.dispose();
    });

    testWidgets('is at least 48 high', (tester) async {
      await pump(tester, OptionState.idle);
      expect(tester.getSize(find.byType(OptionTile)).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('StateMessage', () {
    testWidgets('loading says what is happening in words', (tester) async {
      await tester.pumpWidget(_host(const StateMessage(
          kind: StateKind.loading,
          title: 'Opening Sprichst',
          message: 'Getting your lessons ready.')));
      expect(find.text('Opening Sprichst'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the arc stops under reduced motion', (tester) async {
      await tester.pumpWidget(_host(
          const StateMessage(
              kind: StateKind.loading, title: 'Saving', message: 'One moment.'),
          reduceMotion: true));
      final arc = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(arc.value, isNotNull, reason: 'a fixed value does not spin');
    });

    testWidgets('an error offers a way to try again', (tester) async {
      var retried = false;
      await tester.pumpWidget(_host(StateMessage(
          kind: StateKind.error,
          title: 'Couldn’t reach Groq',
          message: 'Lessons and reviews still work offline.',
          actionLabel: 'Try again',
          onAction: () => retried = true)));
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });
  });

  group('WeekActivity', () {
    const days = [
      DayMinutes('Mo', 12),
      DayMinutes('Tu', 18),
      DayMinutes('We', 0),
      DayMinutes('Th', 22),
      DayMinutes('Fr', 9, today: true),
      DayMinutes('Sa', 0),
      DayMinutes('Su', 0),
    ];

    testWidgets(
        'gives the numbers in words, so the chart is not the only source',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const WeekActivity(days: days, goal: 15)));
      final label = tester.getSemantics(find.byType(WeekActivity)).label;
      expect(label, contains('Mo 12 min'));
      expect(label, contains('We no activity'));
      expect(label, contains('Goal 15 minutes'));
      handle.dispose();
    });
  });

  group('Wordmark and icon', () {
    testWidgets('the wordmark is named and does not grow with text size',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const Wordmark()));
      final normal = tester.getSize(find.byType(Wordmark));
      expect(tester.getSemantics(find.byType(Wordmark)).label, 'Sprichst');

      await tester.pumpWidget(_host(const Wordmark(), textScale: 2));
      expect(tester.getSize(find.byType(Wordmark)), normal);
      handle.dispose();
    });

    testWidgets('the orbit mark follows the theme', (tester) async {
      Future<String> asset(Brightness b) async {
        await tester.pumpWidget(_host(const AppIcon(), brightness: b));
        await tester.pumpAndSettle(); // the theme change animates
        final image = tester.widget<Image>(find.byType(Image));
        return (image.image as AssetImage).assetName;
      }

      expect(await asset(Brightness.light), endsWith('orbit-light.png'));
      expect(await asset(Brightness.dark), endsWith('orbit-dark.png'));
    });
  });

  group('FeedbackBanner', () {
    testWidgets('every tone pairs an icon with a word', (tester) async {
      for (final (tone, icon) in [
        (BannerTone.success, Icons.check_circle),
        (BannerTone.danger, Icons.cancel_outlined),
        (BannerTone.warning, Icons.warning_amber_rounded),
        (BannerTone.offline, Icons.cloud_off),
        (BannerTone.info, Icons.info_outline),
      ]) {
        await tester.pumpWidget(
            _host(FeedbackBanner(tone: tone, title: 'Title', message: 'Body')));
        expect(find.byIcon(icon), findsOneWidget, reason: '$tone');
        expect(find.text('Title'), findsOneWidget);
      }
    });

    testWidgets('an answer says Correct or Not quite, never Wrong',
        (tester) async {
      await tester.pumpWidget(_host(const FeedbackBanner.answer(
          correct: false, message: 'Gehen takes sein.')));
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.textContaining('Wrong'), findsNothing);
    });
  });

  group('screens', () {
    final learner = LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1);

    testWidgets('each main screen has at most one feature panel',
        (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(learner));
      for (final tab in ['Home', 'Learn', 'Practice', 'Coach']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
            find.byType(FeaturePanel).evaluate().length, lessThanOrEqualTo(1),
            reason: tab);
      }
    });

    testWidgets('Home opens with the date as its eyebrow and the greeting',
        (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(learner));
      expect(
          find.textContaining(
              RegExp(r'^(MON|TUES|WEDNES|THURS|FRI|SATUR|SUN)DAY, ')),
          findsOneWidget);
      expect(find.textContaining('Guten'), findsOneWidget);
      expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    });

    testWidgets('every top-level screen carries the masthead', (tester) async {
      await pumpSprichst(tester,
          size: const Size(390, 844),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(learner));
      for (final tab in ['Home', 'Learn', 'Practice', 'Coach']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(find.byType(Wordmark), findsOneWidget, reason: tab);
      }
    });
  });
}
