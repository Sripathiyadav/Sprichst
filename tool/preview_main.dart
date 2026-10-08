// Visual preview: runs the real app with a fake signed-in learner and seeded
// progress, so screens can be inspected without Google sign-in or Firebase.
//
//   flutter run -t tool/preview_main.dart
//
// Options (all optional), passed as --dart-define:
//   PREVIEW_APPEARANCE = light | dark | system   (default system)
//   PREVIEW_STYLE      = glass | standard        (default glass)
//   PREVIEW_INTENSITY  = 0..100                  (default 60)
//   PREVIEW_GOAL       = everyday | travel | work | goethe | testdaf
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprichst/app/app.dart';
import 'package:sprichst/app/app_controller.dart';
import 'package:sprichst/data/ai/mock_ai_repository.dart';
import 'package:sprichst/data/local/local_learning_repository.dart';
import 'package:sprichst/domain/learning/achievements.dart';
import 'package:sprichst/domain/learning/exercise_evaluator.dart';
import 'package:sprichst/domain/learning/flashcard_deck.dart';
import 'package:sprichst/domain/learning/flashcard_scheduler.dart';
import 'package:sprichst/domain/learning/progress_tracker.dart';
import 'package:sprichst/domain/models/curriculum.dart';
import 'package:sprichst/domain/models/dialogue_models.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/domain/repositories/auth_repository.dart';
import 'package:sprichst/domain/repositories/learning_repository.dart';
import 'package:sprichst/features/auth/auth_view_model.dart';

const _appearance = String.fromEnvironment('PREVIEW_APPEARANCE');
const _style = String.fromEnvironment('PREVIEW_STYLE');
const _goal = String.fromEnvironment('PREVIEW_GOAL');
const _intensity = int.fromEnvironment('PREVIEW_INTENSITY', defaultValue: 60);

class _PreviewUser implements User {
  @override
  String get uid => 'preview';

  @override
  String? get email => 'learner@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewAuth implements AuthRepository {
  @override
  User? get currentUser => _PreviewUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> signOut() async {}
}

/// Lessons come from the real bundled course; the profile lives in memory and
/// starts with some history, including a missed exercise that is due.
class _PreviewLearning implements LearningRepository {
  final _lessons = LocalLearningRepository();
  LearningProfile? _profile;

  @override
  Future<List<Lesson>> loadLessons() => _lessons.loadLessons();

  @override
  Future<List<Dialogue>> loadDialogues() => _lessons.loadDialogues();

  @override
  Future<LearningProfile?> loadProfile() async {
    if (_profile != null) return _profile;
    final curriculum = Curriculum(await loadLessons());
    const tracker = ProgressTracker();
    const evaluator = ExerciseEvaluator();
    final now = DateTime.now().subtract(const Duration(days: 1));

    var profile = LearningProfile.newLearner(
            nativeLanguage: 'English', currentLevel: CefrLevel.a1)
        .copyWith(
      name: 'Sam',
      appearancePreference:
          AppearancePreference.values.asNameMap()[_appearance] ??
              AppearancePreference.system,
      surfaceStyle:
          SurfaceStyle.values.asNameMap()[_style] ?? SurfaceStyle.glass,
      glassIntensity: _intensity,
      goal: LearningGoal.values.asNameMap()[_goal] ?? LearningGoal.everyday,
    );
    for (final id in ['a1_articles', 'a1_sein']) {
      final lesson = curriculum.lessonById(id)!;
      // Miss the article exercises so a weak skill and due reviews show up.
      final results = [
        for (final e in lesson.exercises)
          evaluator.evaluate(
              e, id == 'a1_articles' && e.id != 'article_3' ? 'x' : e.answer),
      ];
      profile = tracker
          .completeLesson(profile, lesson, curriculum, results, now: now)
          .profile;
    }

    // Some flashcard history, a game played, and the badges they earn.
    const deck = FlashcardDeck();
    final session = deck.session(profile, curriculum, now, limit: 8);
    profile = tracker
        .completeFlashcards(
          profile,
          [
            for (final (i, card) in session.indexed)
              CardReview(card, i.isEven ? CardRating.good : CardRating.hard),
          ],
          now: now,
        )
        .profile;
    profile =
        Achievements.apply(profile, const QuestEvent(lessons: 1), now).profile;
    return _profile = profile;
  }

  @override
  Future<void> saveProfile(LearningProfile profile) async => _profile = profile;

  @override
  Future<void> deleteLearningData() async => _profile = null;
}

void main() {
  runApp(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_PreviewAuth()),
      learningRepositoryProvider.overrideWithValue(_PreviewLearning()),
      aiRepositoryProvider.overrideWithValue(MockAIRepository()),
    ],
    child: const SprichstApp(),
  ));
}
