import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/data/profile_codec.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

LearningProfile _profile({
  SurfaceStyle style = SurfaceStyle.glass,
  int intensity = 60,
}) =>
    LearningProfile.newLearner(
      nativeLanguage: 'English',
      currentLevel: CefrLevel.a1,
    ).copyWith(surfaceStyle: style, glassIntensity: intensity);

const _phone = Size(390, 844);

/// A glass card on its own, under a chosen theme and MediaQuery.
Widget _card({
  required GlassTheme glass,
  bool highContrast = false,
  bool blur = false,
}) =>
    MaterialApp(
      theme: SprichstTheme.build(Brightness.light, glass: glass),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Scaffold(
            body: Center(
              child: GlassSurface(blur: blur, child: const Text('Hello')),
            ),
          ),
        ),
      ),
    );

void main() {
  group('defaults and storage', () {
    test('new learners get the standard paper-and-panel surfaces', () {
      final profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.preA1);
      expect(profile.surfaceStyle, SurfaceStyle.standard);
      expect(profile.glassIntensity, LearningProfile.defaultGlassIntensity);
    });

    test('style and intensity survive encoding, and intensity is clamped', () {
      final stored = ProfileCodec.encode(
        _profile(style: SurfaceStyle.standard, intensity: 35),
        encodeDate: (d) => d.toIso8601String(),
      );
      final decoded = ProfileCodec.decode(stored,
          decodeDate: (raw) => DateTime.parse(raw as String));
      expect(decoded.surfaceStyle, SurfaceStyle.standard);
      expect(decoded.glassIntensity, 35);

      stored['glassIntensity'] = 900;
      expect(
        ProfileCodec.decode(stored,
            decodeDate: (raw) => DateTime.parse(raw as String)).glassIntensity,
        100,
      );
    });

    test('profiles saved before the setting existed default to standard', () {
      final decoded = ProfileCodec.decode({'name': 'Sam'},
          decodeDate: (raw) => DateTime.parse(raw as String));
      expect(decoded.surfaceStyle, SurfaceStyle.standard);
      expect(decoded.glassIntensity, LearningProfile.defaultGlassIntensity);
    });

    test('resetting progress keeps the learner’s look', () {
      final reset = _profile(style: SurfaceStyle.standard, intensity: 20)
          .resetLearningProgress();
      expect(reset.surfaceStyle, SurfaceStyle.standard);
      expect(reset.glassIntensity, 20);
    });
  });

  group('GlassSurface', () {
    testWidgets('blurs only when asked, and only in glass mode',
        (tester) async {
      final glass = GlassTheme.fromProfile(SurfaceStyle.glass, 60);

      // MaterialApp animates theme changes, so settle after every pump.
      Future<void> show(Widget widget) async {
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();
      }

      await show(_card(glass: glass));
      expect(find.byType(BackdropFilter), findsNothing,
          reason: 'ordinary cards never blur');

      await show(_card(glass: glass, blur: true));
      expect(find.byType(BackdropFilter), findsOneWidget);

      await show(_card(glass: GlassTheme.standard, blur: true));
      expect(find.byType(BackdropFilter), findsNothing,
          reason: 'standard mode is flat even when blur is requested');
    });

    testWidgets('reduced transparency (high contrast) turns glass off',
        (tester) async {
      final glass = GlassTheme.fromProfile(SurfaceStyle.glass, 100);
      await tester
          .pumpWidget(_card(glass: glass, blur: true, highContrast: true));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('blur strength follows intensity', (tester) async {
      Future<double> sigma(int percent) async {
        await tester.pumpWidget(_card(
          glass: GlassTheme.fromProfile(SurfaceStyle.glass, percent),
          blur: true,
        ));
        await tester.pumpAndSettle();
        final filter =
            tester.widget<BackdropFilter>(find.byType(BackdropFilter));
        // The blur filter prints as "ImageFilter.blur(sigmaX, sigmaY, ...)".
        final match =
            RegExp(r'blur\(([\d.]+)').firstMatch(filter.filter.toString());
        return double.parse(match!.group(1)!);
      }

      final strong = await sigma(100);
      final subtle = await sigma(0);
      expect(strong, greaterThan(subtle));
    });
  });

  group('shell', () {
    testWidgets('the navigation bar is plain and opaque', (tester) async {
      await pumpSprichst(tester,
          size: _phone,
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_profile()));
      // Liquid Glass belonged to the previous look: even a profile saved with
      // it draws the design system's flat surfaces now.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('on wide screens the rail replaces the bar', (tester) async {
      await pumpSprichst(tester,
          size: const Size(1280, 800),
          brightness: Brightness.dark,
          repository: InMemoryLearningRepository(_profile()));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Appearance settings', () {
    Future<InMemoryLearningRepository> open(WidgetTester tester) async {
      final repository = InMemoryLearningRepository(_profile());
      await pumpSprichst(tester,
          size: const Size(1200, 900),
          brightness: Brightness.light,
          repository: repository);
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('offers light, dark or the device setting, and nothing else',
        (tester) async {
      await open(tester);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Liquid Glass'), findsNothing);
    });

    testWidgets('choosing Dark saves it and the app follows', (tester) async {
      final repository = await open(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
          repository.profile!.appearancePreference, AppearancePreference.dark);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark);
    });

    testWidgets('the Account row says which mode is chosen', (tester) async {
      await pumpSprichst(tester,
          size: const Size(1200, 900),
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_profile()));
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      expect(find.text('Use device setting'), findsOneWidget);
    });
  });

  // The whole app must stay usable and legible whichever look is chosen.
  final looks = <String, LearningProfile>{
    'standard': _profile(style: SurfaceStyle.standard),
    'a profile saved with glass': _profile(intensity: 100),
  };
  for (final entry in looks.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} in ${brightness.name}: no overflow, accessible',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSprichst(tester,
            size: _phone,
            brightness: brightness,
            repository: InMemoryLearningRepository(entry.value));

        for (final label in ['Home', 'Learn', 'Practice', 'Coach']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
              reason: '$label tap targets');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
              reason: '$label labels');
          if (label != 'Coach') {
            await expectLater(tester, meetsGuideline(textContrastGuideline),
                reason: '$label contrast');
          }
        }
        handle.dispose();
      });
    }
  }

  // Silence the unused-import warning for dart:ui in some analyzer versions.
  test('the blur filter type is the engine’s', () {
    expect(ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1), isA<ui.ImageFilter>());
  });
}
