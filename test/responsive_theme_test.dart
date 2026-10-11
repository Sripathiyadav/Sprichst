import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

const _sizes = <String, Size>{
  'small phone': Size(320, 568),
  'phone': Size(390, 844),
  'landscape phone': Size(740, 360),
  'tablet': Size(820, 1180),
  'desktop': Size(1440, 900),
};

LearningProfile _profile() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.a1);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('shell screens fit on $name in ${brightness.name} mode',
          (tester) async {
        await pumpSprichst(tester,
            size: size,
            brightness: brightness,
            repository: InMemoryLearningRepository(_profile()));

        final context = tester.element(find.byType(Scaffold).first);
        expect(Theme.of(context).brightness, brightness);

        final usesRail = size.width >= 600;
        for (final label in ['Home', 'Learn', 'Practice', 'Coach']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }

        if (usesRail) {
          for (final label in ['Progress', 'Account']) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: label);
          }
        } else {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          for (final label in ['Progress', 'Account']) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            expect(find.byType(BackButton), findsOneWidget);
            expect(tester.takeException(), isNull, reason: label);
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('lesson and onboarding fit on $name', (tester) async {
      await pumpSprichst(tester,
          size: size,
          brightness: Brightness.dark,
          repository: InMemoryLearningRepository());
      // No profile yet: onboarding.
      expect(find.text('Start'), findsOneWidget);
      await _tapVisible(tester, find.text('Start'));
      await _tapVisible(tester, find.text('Continue')); // language
      await _tapVisible(tester, find.text('Continue')); // level
      expect(find.text('What do you want German for?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('Build my learning plan'));

      // Lesson: intro then first exercise.
      await tester.tap(find.text('Learn').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Greetings').first);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Start practice'));
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('appearance setting switches the app theme and persists',
      (tester) async {
    final repository = InMemoryLearningRepository(_profile());
    await pumpSprichst(tester,
        size: _sizes['desktop']!,
        brightness: Brightness.light,
        repository: repository);

    expect(_themeMode(tester), ThemeMode.system);

    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(_themeMode(tester), ThemeMode.dark);
    expect(repository.profile!.appearancePreference, AppearancePreference.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.light);
  });
}
