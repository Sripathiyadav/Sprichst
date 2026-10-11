import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

import 'support/fakes.dart';

LearningProfile _learner({int streak = 0}) => LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1)
    .copyWith(
        name: 'Mord',
        streak: streak,
        lastStudyDate: streak > 0 ? DateTime.now() : null);

Future<void> _pump(WidgetTester tester, LearningProfile profile,
    {double textScale = 1}) async {
  await pumpSprichst(tester,
      size: const Size(390, 844),
      brightness: Brightness.light,
      textScale: textScale,
      repository: InMemoryLearningRepository(profile));
}

void main() {
  testWidgets('the streak sits beside the level ring; quests span the width',
      (tester) async {
    await _pump(tester, _learner(streak: 3));
    final ring = find.byKey(const ValueKey('level-ring'));
    expect(ring, findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('DAY STREAK'), findsOneWidget);
    // Ring right of the streak, on the same row.
    final streakBox = tester.getRect(find.text('DAY STREAK'));
    final ringBox = tester.getRect(ring);
    expect(ringBox.left, greaterThan(streakBox.right));
    // The quests meter and the button use the full content width.
    final meter = tester.getSize(find.byType(SkillMeter).first);
    final button = tester.getSize(find.byKey(const ValueKey('start-quests')));
    expect(meter.width, button.width);
    expect(meter.width, greaterThan(390 - 2 * 24));
    expect(find.text('Start today’s quests'), findsOneWidget);
  });

  testWidgets('without a streak the invitation shows next to the ring',
      (tester) async {
    await _pump(tester, _learner());
    expect(find.text('Finish a lesson today to start your streak.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('level-ring')), findsOneWidget);
  });

  testWidgets('Start today’s quests opens the first unfinished quest',
      (tester) async {
    await _pump(tester, _learner());
    await tester.tap(find.byKey(const ValueKey('start-quests')));
    await tester.pumpAndSettle();
    // The first quest is "finish a lesson": a lesson opens.
    expect(find.text('Start practice'), findsOneWidget);
  });

  testWidgets('the top-right avatar opens the account details', (tester) async {
    await _pump(tester, _learner());
    await tester.tap(find.byKey(const ValueKey('home-account')));
    await tester.pumpAndSettle();
    expect(find.text('Learning preferences'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('pulling down refreshes, and so does the logo', (tester) async {
    await _pump(tester, _learner());
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(
        find.text('Could not refresh. Check your connection.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('logo-refresh')));
    await tester.pumpAndSettle();
  });

  testWidgets('fits at large text', (tester) async {
    await _pump(tester, _learner(streak: 5), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('level-ring')), findsOneWidget);
  });
}
