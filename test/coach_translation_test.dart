import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

/// A tutor whose question comes with its English, or without.
class _Tutor extends MockAIRepository {
  _Tutor(this.translation);
  final String translation;

  @override
  Future<TutorReply> chat(String message, TutorContext context) async =>
      TutorReply(
        reply: 'Schön!',
        followUp: 'Was machst du heute Abend?',
        followUpTranslation: translation,
      );
}

Future<void> _ask(WidgetTester tester, String translation) async {
  await pumpSprichst(
    tester,
    size: const Size(390, 900),
    brightness: Brightness.light,
    repository: InMemoryLearningRepository(LearningProfile.newLearner(
        nativeLanguage: 'English', currentLevel: CefrLevel.a1)),
    extraOverrides: [
      aiRepositoryProvider.overrideWithValue(_Tutor(translation)),
    ],
  );
  await tester.tap(find.text('Coach').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'Hallo');
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tutor\'s question is shown with its English meaning',
      (tester) async {
    await _ask(tester, 'What are you doing this evening?');
    expect(find.textContaining('Was machst du heute Abend?'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-translation')), findsOneWidget);
    expect(find.text('What are you doing this evening?'), findsOneWidget);
  });

  testWidgets('no translation means nothing is invented', (tester) async {
    await _ask(tester, '');
    expect(find.textContaining('Was machst du heute Abend?'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-translation')), findsNothing);
  });
}
