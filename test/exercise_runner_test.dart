import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/learn/exercises/exercise_runner.dart';

const _exercises = [
  Exercise(
    id: 'mc',
    prompt: 'Pick the article for Tisch',
    options: ['der', 'die', 'das'],
    answer: 'der',
    explanation: 'Masculine.',
    skills: ['definite_articles'],
  ),
  Exercise(
    id: 'typed',
    kind: ExerciseKind.fillBlank,
    prompt: 'Type the article: ___ Lampe',
    answer: 'die',
    explanation: 'Feminine.',
    skills: ['definite_articles'],
  ),
  Exercise(
    id: 'order',
    kind: ExerciseKind.wordOrder,
    prompt: 'Build the sentence',
    options: ['heiße', 'Sam', 'Ich'],
    answer: 'Ich heiße Sam',
    explanation: 'Verb second.',
    skills: ['word_order'],
  ),
];

void main() {
  testWidgets('runs choice, typed, and word-order exercises to completion',
      (tester) async {
    List<ExerciseResult>? finished;
    await tester.pumpWidget(MaterialApp(
      theme: SprichstTheme.light,
      home: Scaffold(
        body: ExerciseRunner(
          exercises: _exercises,
          onFinished: (results) async => finished = results,
        ),
      ),
    ));

    final check = find.widgetWithText(FilledButton, 'Check answer');
    expect(tester.widget<FilledButton>(check).onPressed, isNull);

    // Multiple choice: a wrong pick is graded and the answer is revealed.
    await tester.tap(find.text('die'));
    await tester.pump();
    await tester.tap(check);
    await tester.pump();
    expect(find.textContaining('Correct answer: der'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Typed answer.
    await tester.enterText(find.byType(TextField), 'die');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Check answer'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Word order stays disabled until every word is placed.
    await tester.tap(find.widgetWithText(ActionChip, 'Ich'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Check answer'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'heiße'));
    await tester.tap(find.widgetWithText(ActionChip, 'Sam'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Check answer'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pump();

    expect(finished!.map((r) => r.isCorrect), [false, true, true]);
  });
}
