import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

LearningProfile _learner() => LearningProfile.newLearner(
    nativeLanguage: 'English', currentLevel: CefrLevel.a1);

void main() {
  testWidgets(
      'the welcome screen and the first step say more languages are coming',
      (tester) async {
    await pumpSprichst(tester,
        size: const Size(390, 900),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository());
    expect(find.text('More languages coming soon.'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tour-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('more-languages')), findsOneWidget);
    expect(find.text(MoreLanguagesNote.title), findsOneWidget);
    // Informational: no request button during onboarding.
    expect(find.byKey(const ValueKey('request-language')), findsNothing);
  });

  testWidgets('Learn carries the note too', (tester) async {
    await pumpSprichst(tester,
        size: const Size(390, 3000),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_learner()));
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    final note = find.byKey(const ValueKey('more-languages'));
    await tester.dragUntilVisible(
        note, find.byType(ListView).first, const Offset(0, -1500));
    expect(note, findsOneWidget);
  });

  testWidgets('Account lists German and lets the learner request a language',
      (tester) async {
    await pumpSprichst(tester,
        size: const Size(390, 1400),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(_learner()));
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learning preferences'));
    await tester.pumpAndSettle();
    expect(find.text('LANGUAGE YOU ARE LEARNING'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    expect(find.text(MoreLanguagesNote.title), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('request-language')));
    await tester.tap(find.byKey(const ValueKey('request-language')));
    await tester.pumpAndSettle();
    // The contact form opens as a feature request, with a starting sentence.
    expect(find.text('Contact developer'), findsOneWidget);
    expect(find.textContaining('I would like to learn this language'),
        findsOneWidget);
  });
}
