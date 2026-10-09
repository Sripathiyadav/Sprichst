import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/data/profile_codec.dart';
import 'package:sprichst/domain/games/game_models.dart';
import 'package:sprichst/domain/learning/achievements.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/learning/flashcard_scheduler.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/learning_models.dart';

import 'support/fakes.dart';

/// The Firestore security rules (firebase/firestore.rules) validate the exact
/// document the app writes. This test encodes a realistic, fully populated
/// profile with the real [ProfileCodec] and compares it with the fixture that
/// the rules tests use, so the rules and the app cannot drift apart.
///
/// After changing the schema, regenerate the fixture with
///   UPDATE_FIXTURE=1 flutter test test/firestore_profile_fixture_test.dart
/// then run `npm test` in firebase/ and update firestore.rules if it fails.
const _fixturePath = 'firebase/tests/fixtures/real_profile.json';

/// Dates become {"__timestamp": ISO-8601} so the JS tests can turn them back
/// into Firestore Timestamps, which is what the app really sends.
Object _date(DateTime date) => {'__timestamp': date.toUtc().toIso8601String()};

LearningProfile _richProfile() {
  final curriculum = Curriculum(loadCourse());
  const tracker = ProgressTracker();
  const evaluator = ExerciseEvaluator();
  final now = DateTime.utc(2026, 10, 8, 9);
  var profile = LearningProfile.newLearner(
          nativeLanguage: 'English', currentLevel: CefrLevel.a1)
      .copyWith(name: 'Sam', goal: LearningGoal.goethe);

  for (final id in ['a1_articles', 'a1_sein']) {
    final lesson = curriculum.lessonById(id)!;
    final results = [
      for (final e in lesson.exercises)
        evaluator.evaluate(e, e.id.endsWith('1') ? 'x' : e.answer),
    ];
    profile = tracker
        .completeLesson(profile, lesson, curriculum, results, now: now)
        .profile;
  }
  final session = const FlashcardDeck().session(profile, curriculum, now);
  profile = tracker
      .completeFlashcards(
        profile,
        [
          for (final (i, card) in session.indexed)
            CardReview(card, i.isEven ? CardRating.good : CardRating.again),
        ],
        now: now,
      )
      .profile;
  profile = tracker
      .completeGame(
        profile,
        const GameOutcome(
          game: GameId.wortle,
          score: 85,
          correct: 1,
          total: 1,
          stars: 3,
          bestCombo: 0,
          results: [],
        ),
        now: now,
      )
      .profile;
  return Achievements.apply(profile, const QuestEvent(lessons: 1), now).profile;
}

void main() {
  test('the real profile document matches the fixture used by the rules tests',
      () {
    final encoded = ProfileCodec.encode(_richProfile(), encodeDate: _date);
    final json = const JsonEncoder.withIndent('  ').convert(encoded);

    if (Platform.environment['UPDATE_FIXTURE'] == '1') {
      File(_fixturePath).writeAsStringSync('$json\n');
    }

    expect(File(_fixturePath).readAsStringSync().trim(), json.trim(),
        reason: 'The profile schema changed. Regenerate the fixture '
            '(UPDATE_FIXTURE=1 flutter test ${_fixturePath.split('/').last}) '
            'and re-run the Firestore rules tests.');
  });

  test('the fixture is rich enough to exercise every field', () {
    final data = jsonDecode(File(_fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    for (final key in [
      'lessonProgress',
      'skillStats',
      'exerciseStats',
      'flashcards',
      'gamification',
      'reviewItems',
      'lastStudyDate',
    ]) {
      expect(data[key], isNotNull, reason: key);
    }
    expect((data['flashcards'] as Map)['states'], isNotEmpty);
    expect(data['reviewItems'], isNotEmpty);
  });
}
