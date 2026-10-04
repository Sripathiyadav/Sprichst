import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/review_scheduler.dart';
import '../data/ai/http_ai_repository.dart';
import '../data/firestore/firestore_learning_repository.dart';
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

  bool isLoading = true;
  LearningProfile? profile;
  List<Lesson> lessons = const [];
  String? error;

  bool get isOnboarded => profile != null;
  int get dueReviews =>
      profile?.reviewItems.where((item) => item.isDue).length ?? 0;
  Lesson? get currentLesson {
    if (profile == null || lessons.isEmpty) return null;
    return lessons.firstWhere(
      (lesson) => lesson.id == profile!.currentLessonId,
      orElse: () => lessons.first,
    );
  }

  Future<void> initialize() async {
    try {
      lessons = await _learningRepository.loadLessons();
      profile = await _learningRepository.loadProfile();
    } catch (_) {
      error = 'We could not restore your saved learning state.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding(
      {required String language, required CefrLevel level}) async {
    profile = LearningProfile.newLearner(
        nativeLanguage: language, currentLevel: level);
    await _persist();
    notifyListeners();
  }

  Future<void> completeLesson(Lesson lesson,
      {required int correctAnswers}) async {
    final before = profile;
    if (before == null) return;
    final completed = {...before.completedLessonIds, lesson.id}.toList();
    final nextIndex = lessons.indexWhere((item) => item.id == lesson.id) + 1;
    final nextId =
        nextIndex < lessons.length ? lessons[nextIndex].id : lesson.id;
    final scoreLift = correctAnswers / lesson.exercises.length * .08;
    final review = ReviewItem(
      id: 'lesson-${lesson.id}',
      label: lesson.title,
      kind: 'Lesson recall',
      dueAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    profile = before.copyWith(
      currentLessonId: nextId,
      completedLessonIds: completed,
      reviewItems: [
        ...before.reviewItems.where((item) => item.id != review.id),
        review
      ],
      scores:
          before.scores.boosted(vocabulary: scoreLift, grammar: scoreLift / 2),
      xp: before.xp + (correctAnswers * 10),
      streak: before.streak == 0 ? 1 : before.streak,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> rateReview(ReviewItem item, ReviewRating rating) async {
    final before = profile;
    if (before == null) return;
    final rescheduled = _scheduler.schedule(item, rating);
    profile = before.copyWith(
      reviewItems: [
        for (final existing in before.reviewItems)
          if (existing.id == item.id) rescheduled else existing,
      ],
      xp: before.xp + (rating == ReviewRating.again ? 2 : 5),
    );
    await _persist();
    notifyListeners();
  }

  Future<CoachReply> correctGerman(String text) async {
    final currentProfile = profile;
    if (currentProfile == null) {
      throw StateError('Complete onboarding before chatting with the coach.');
    }
    return _aiRepository.correctGerman(text, currentProfile);
  }

  Future<TutorReply> chat(String message) async {
    final currentProfile = profile;
    if (currentProfile == null) {
      throw StateError('Complete onboarding before chatting with the coach.');
    }

    return _aiRepository.chat(message, currentProfile);
  }

  Future<void> _persist() async {
    final currentProfile = profile;
    if (currentProfile != null) {
      await _learningRepository.saveProfile(currentProfile);
    }
  }
}
