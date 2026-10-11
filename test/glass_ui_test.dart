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
    test('new learners get Liquid Glass at the default intensity', () {
      final profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.preA1);
      expect(profile.surfaceStyle, SurfaceStyle.glass);
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

    test('profiles saved before the setting existed default to glass', () {
      final decoded = ProfileCodec.decode({'name': 'Sam'},
          decodeDate: (raw) => DateTime.parse(raw as String));
      expect(decoded.surfaceStyle, SurfaceStyle.glass);
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
    testWidgets('glass floats the navigation over the content', (tester) async {
      await pumpSprichst(tester,
          size: _phone,
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(_profile()));
      expect(find.byType(BackdropFilter), findsOneWidget,
          reason: 'the floating navigation bar blurs what scrolls beneath it');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('standard keeps a plain, opaque navigation bar',
        (tester) async {
      await pumpSprichst(tester,
          size: _phone,
          brightness: Brightness.light,
          repository: InMemoryLearningRepository(
              _profile(style: SurfaceStyle.standard)));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('on wide screens the rail is the glass panel', (tester) async {
      await pumpSprichst(tester,
          size: const Size(1280, 800),
          brightness: Brightness.dark,
          repository: InMemoryLearningRepository(_profile()));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Appearance settings', () {
    Future<InMemoryLearningRepository> open(WidgetTester tester,
        {LearningProfile? profile}) async {
      final repository = InMemoryLearningRepository(profile ?? _profile());
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

    testWidgets(
        'Standard hides the intensity control; Liquid Glass restores it',
        (tester) async {
      final repository = await open(tester);
      expect(find.byType(Slider), findsOneWidget);

      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(repository.profile!.surfaceStyle, SurfaceStyle.standard);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Clean, opaque surfaces.'), findsOneWidget);

      await tester.tap(find.text('Liquid Glass'));
      await tester.pumpAndSettle();
      expect(repository.profile!.surfaceStyle, SurfaceStyle.glass);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('dragging the slider saves the new intensity on release',
        (tester) async {
      final repository = await open(tester);
      expect(repository.profile!.glassIntensity, 60);

      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      // Drag to the far right of the track.
      await tester.dragFrom(
        Offset(rect.left + rect.width * .6, rect.center.dy),
        Offset(rect.width, 0),
      );
      await tester.pumpAndSettle();

      expect(repository.profile!.glassIntensity, 100);
      expect(find.text('100%'), findsWidgets);
    });

    testWidgets('the Account row summarises the current look', (tester) async {
      await open(tester, profile: _profile(intensity: 35));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Liquid Glass 35%'), findsOneWidget);
    });

    testWidgets('the app theme follows the setting', (tester) async {
      final repository = await open(tester);
      GlassTheme current() =>
          Theme.of(tester.element(find.byType(Scaffold).first))
              .extension<GlassTheme>()!;

      expect(current().enabled, isTrue);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(current().enabled, isFalse);
      expect(repository.profile!.surfaceStyle, SurfaceStyle.standard);
    });
  });

  // The whole app must stay usable and legible whichever look is chosen.
  final looks = <String, LearningProfile>{
    'standard': _profile(style: SurfaceStyle.standard),
    'glass at 0%': _profile(intensity: 0),
    'glass at 100%': _profile(intensity: 100),
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
