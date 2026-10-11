import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/learn/exercises/exercise_runner.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

Widget _host(Widget child) => MaterialApp(
      theme: SprichstTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets(
      'empty, error and offline states are drawn, loading keeps its arc',
      (tester) async {
    for (final kind in [StateKind.empty, StateKind.error, StateKind.offline]) {
      await tester.pumpWidget(
          _host(StateMessage(kind: kind, title: 'T', message: 'M')));
      await tester.pumpAndSettle();
      expect(find.byType(Lottie), findsOneWidget, reason: kind.name);
      expect(find.text('T'), findsOneWidget);
    }
    await tester.pumpWidget(_host(
        const StateMessage(kind: StateKind.loading, title: 'T', message: 'M')));
    expect(find.byType(Lottie), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('answer feedback animates but always says the word',
      (tester) async {
    await tester.pumpWidget(
        _host(const FeedbackBanner.answer(correct: true, message: 'Richtig.')));
    await tester.pumpAndSettle();
    expect(find.byType(Lottie), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    await tester.pumpWidget(
        _host(const FeedbackBanner.answer(correct: false, message: 'Falsch.')));
    await tester.pumpAndSettle();
    expect(find.byType(Lottie), findsOneWidget);
    expect(find.text('Not quite'), findsOneWidget);
    // Other banners keep their icon.
    await tester.pumpWidget(_host(const FeedbackBanner(
        tone: BannerTone.danger, title: 'Oops', message: 'No.')));
    expect(find.byType(Lottie), findsNothing);
  });

  testWidgets('the summary shows the streak and level-up only when earned',
      (tester) async {
    Future<void> pump({int streak = 0, CefrLevel? level}) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(SizedBox(
        height: 1500,
        child: SessionSummary(
            title: 'Done',
            correct: 3,
            total: 4,
            xpEarned: 10,
            streakDays: streak,
            leveledUpTo: level),
      )));
      await tester.pumpAndSettle();
    }

    await pump();
    expect(find.textContaining('Streak'), findsNothing);
    await pump(streak: 1);
    expect(find.text('Streak started: 1 day.'), findsOneWidget);
    await pump(streak: 6, level: CefrLevel.a2);
    expect(find.text('Streak kept: 6 days in a row.'), findsOneWidget);
    expect(find.text('New level'), findsOneWidget);
  });

  testWidgets('the selected tab sits on the animated pill', (tester) async {
    await pumpSprichst(tester,
        size: const Size(390, 844),
        brightness: Brightness.light,
        repository: InMemoryLearningRepository(LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)));
    expect(find.byType(Lottie), findsWidgets);
    final before = tester.widgetList<Lottie>(find.byType(Lottie)).length;
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    expect(tester.widgetList<Lottie>(find.byType(Lottie)).length, before);
  });
}
