import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/account/account_view.dart';

import 'support/fakes.dart';

Future<void> _openCoach(WidgetTester tester,
    {Map<String, Object> storage = const {}}) async {
  await pumpSprichst(
    tester,
    size: const Size(390, 900),
    brightness: Brightness.light,
    repository: InMemoryLearningRepository(LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1)),
    storage: storage,
  );
  await tester.tap(find.text('Coach').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first visit explains how to set up and use the coach',
      (tester) async {
    await _openCoach(tester);
    expect(find.text('Meet your coach'), findsOneWidget);
    expect(find.textContaining('settings button at the top right'),
        findsOneWidget);

    await tester.ensureVisible(find.text('Open coach settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open coach settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AIAndVoicePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Still there until the learner says they have it.
    expect(find.text('Meet your coach'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your coach'), findsNothing);
  });

  testWidgets('once closed, the guide stays closed', (tester) async {
    await _openCoach(tester, storage: {'sprichst_coach_intro_seen_v1': true});
    expect(find.text('Meet your coach'), findsNothing);
  });
}
