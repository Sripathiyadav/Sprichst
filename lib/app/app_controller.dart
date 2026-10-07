import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/review_scheduler.dart';
import '../data/ai/http_ai_repository.dart';
import '../data/firestore/firestore_learning_repository.dart';
import '../domain/learning/exercise_evaluator.dart';
import '../domain/learning/progress_tracker.dart';
import '../domain/models/curriculum.dart';
import '../domain/models/learning_models.dart';
import '../domain/repositories/learning_repository.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return FirestoreLearningRepository();
});
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return HttpAIRepository(
    baseUrl: 'http://127.0.0.1:8000',
  );
});

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  return AppController(
    learningRepository: ref.watch(learningRepositoryProvider),
    aiRepository: ref.watch(aiRepositoryProvider),
  );
});

class AppController extends ChangeNotifier {
  AppController(
      {required LearningRepository learningRepository,
      required AIRepository aiRepository})
      : _learningRepository = learningRepository,
        _aiRepository = aiRepository;

  final LearningRepository _learningRepository;
  final AIRepository _aiRepository;
  final ReviewScheduler _scheduler = const ReviewScheduler();
  final ProgressTracker _tracker = const ProgressTracker();

  bool isLoading = true;
  LearningProfile? profile;
  Curriculum curriculum = Curriculum(const []);
  String? error;

  bool get isOnboarded => profile != null;
  List<Lesson> get lessons => curriculum.lessons;
  int get dueReviews =>
      profile?.reviewItems.where((item) => item.isDue).length ?? 0;
  int get pendingMistakes =>
      profile?.reviewItems
          .where((item) => item.kind == ReviewItem.mistakeKind)
          .length ??
      0;
  List<String> get weakSkills {
    final current = profile;
    return current == null ? const [] : _tracker.weakSkills(current);
  }

  Lesson? get currentLesson {
    final current = profile;
    if (current == null || curriculum.isEmpty) return null;
    return curriculum.lessonById(current.currentLessonId) ??
        curriculum.lessons.first;
  }

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    profile = null;
    notifyListeners();

    try {
      curriculum = Curriculum(await _learningRepository.loadLessons());
      profile = await _learningRepository.loadProfile();
    } catch (_) {
      error = 'We could not restore your saved learning state.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearSession() {
    isLoading = true;
    profile = null;
    curriculum = Curriculum(const []);
    error = null;
    notifyListeners();
  }

  Future<void> completeOnboarding(
      {required String language, required CefrLevel level}) {
    return _commit(LearningProfile.newLearner(
        nativeLanguage: language, currentLevel: level));
  }

  Future<void> updateProfile(LearningProfile updated) => _commit(updated);

  Future<void> resetLearningProgress() async {
    final current = profile;
    if (current == null) return;
    await _commit(current.resetLearningProgress());
  }

  Future<void> deleteLearningData() async {
    await _learningRepository.deleteLearningData();
    profile = null;
    curriculum = Curriculum(const []);
    notifyListeners();
  }

  /// Records that the learner opened [lesson]. Best effort: a failed save must
  /// never stop someone from studying.
  Future<void> startLesson(Lesson lesson) async {
    final before = profile;
    if (before == null) return;
    final started = _tracker.startLesson(before, lesson);
    if (identical(started, before)) return;
    try {
      await _commit(started);
    } catch (_) {}
  }

  /// Applies a finished lesson and returns the XP it earned.
  Future<int> completeLesson(
      Lesson lesson, List<ExerciseResult> results) async {
    final before = profile;
    if (before == null) return 0;
    final update = _tracker.completeLesson(before, lesson, curriculum, results,
        now: DateTime.now());
    await _commit(update.profile);
    return update.xpEarned;
  }

  /// Applies a targeted practice session and returns the XP it earned.
  Future<int> completePractice(List<ExerciseResult> results) async {
    final before = profile;
    if (before == null) return 0;
    final update =
        _tracker.completePractice(before, results, now: DateTime.now());
    await _commit(update.profile);
    return update.xpEarned;
  }

  /// Exercises that train [skillIds], or the learner's weak skills by default.
  List<Exercise> practiceExercises(
          {Iterable<String>? skillIds, int limit = 6}) =>
      curriculum.exercisesForSkills(skillIds ?? weakSkills, limit: limit);

  Future<void> rateReview(ReviewItem item, ReviewRating rating) async {
    final before = profile;
    if (before == null) return;
    final rescheduled = _scheduler.schedule(item, rating);
    await _commit(before.copyWith(
      reviewItems: [
        for (final existing in before.reviewItems)
          if (existing.id == item.id) rescheduled else existing,
      ],
      xp: before.xp + (rating == ReviewRating.again ? 2 : 5),
    ));
  }

  Future<CoachReply> correctGerman(String text) =>
      _aiRepository.correctGerman(text, _requireProfile());

  Future<TutorReply> chat(String message) =>
      _aiRepository.chat(message, _requireProfile());

  LearningProfile _requireProfile() {
    final current = profile;
    if (current == null) {
      throw StateError('Complete onboarding before chatting with the coach.');
    }
    return current;
  }

  /// Shows [next] immediately, then saves it. A failed save rolls the screen
  /// back to the last saved state so the UI never claims what is not stored.
  Future<void> _commit(LearningProfile next) async {
    final previous = profile;
    profile = next;
    notifyListeners();

    try {
      await _learningRepository.saveProfile(next);
    } catch (_) {
      profile = previous;
      error = 'We could not save your changes. Please try again.';
      notifyListeners();
      rethrow;
    }
  }
}
