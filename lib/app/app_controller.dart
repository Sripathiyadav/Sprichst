import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai/http_ai_repository.dart';
import '../data/firestore/firestore_learning_repository.dart';
import '../domain/games/game_models.dart';
import '../domain/games/word_pool.dart';
import '../domain/games/dialogue_game.dart';
import '../domain/learning/achievements.dart';
import '../domain/learning/adaptive_planner.dart';
import '../domain/learning/exam_readiness.dart';
import '../domain/learning/flashcard_deck.dart';
import '../domain/learning/flashcard_scheduler.dart';
import '../domain/learning/learner_insights.dart';
import '../domain/learning/exercise_evaluator.dart';
import '../domain/learning/learning_path.dart';
import '../domain/learning/progress_tracker.dart';
import '../domain/learning/tutor_context_builder.dart';
import '../domain/models/curriculum.dart';
import '../domain/models/dialogue_models.dart';
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
  final ProgressTracker _tracker = const ProgressTracker();
  final LearningPath _path = const LearningPath();
  final AdaptivePlanner _planner = const AdaptivePlanner();
  final TutorContextBuilder _contextBuilder = const TutorContextBuilder();

  final FlashcardDeck _deck = const FlashcardDeck();

  /// Quests finished and badges earned by the most recent session, for the
  /// summary screen to celebrate. Replaced by the next session.
  GamificationResult? lastReward;

  bool isLoading = true;
  LearningProfile? profile;
  Curriculum curriculum = Curriculum(const []);
  List<Dialogue> dialogues = const [];
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

  /// The lesson Sprichst recommends and why, in plain language.
  PathChoice? get recommendation {
    final current = profile;
    return current == null || curriculum.isEmpty
        ? null
        : _path.choose(current, curriculum);
  }

  Lesson? get currentLesson {
    final current = profile;
    if (current == null || curriculum.isEmpty) return null;
    return curriculum.lessonById(current.currentLessonId) ??
        curriculum.lessons.first;
  }

  /// Skills with something to practise: those of lessons already started.
  List<String> get practisableSkills {
    final current = profile;
    return current == null
        ? const []
        : _planner.practisableSkills(current, curriculum);
  }

  /// What the learner should do next, and why.
  DailyPlan? get plan {
    final current = profile;
    return current == null
        ? null
        : _planner.plan(current, curriculum, now: DateTime.now());
  }

  /// Insights drawn from how the learner answers (not from a "learning style").
  List<LearnerInsight> get insights {
    final current = profile;
    return current == null ? const [] : LearnerInsights.build(current);
  }

  ExamReadiness? get examReadiness {
    final current = profile;
    return current == null || !current.goal.isExam
        ? null
        : ExamReadiness.of(current);
  }

  MockExam? buildMockExam() {
    final current = profile;
    return current == null ? null : MockExam.build(current, curriculum);
  }

  DeckSummary get flashcardSummary {
    final current = _requireProfile();
    return _deck.summary(current, curriculum, DateTime.now());
  }

  List<DeckCard> flashcardSession(
      {int limit = FlashcardDeck.defaultSessionLimit}) {
    final current = _requireProfile();
    return _deck.session(current, curriculum, DateTime.now(), limit: limit);
  }

  /// Words for the games: the learner's own first, topped up from a core list.
  List<VocabItem> gameNouns() => WordPool.nouns(_requireProfile(), curriculum);
  List<VocabItem> gameWords() => WordPool.words(_requireProfile(), curriculum);

  List<Dialogue> dialoguesForLearner() {
    final current = _requireProfile();
    return dialoguesFor(
      dialogues,
      current.currentLevel,
      {...current.preferredTopics, ...current.goal.topics},
    );
  }

  Quest? questNamed(String id) => Achievements.todaysQuests(DateTime.now())
      .where((q) => q.id == id)
      .firstOrNull;

  /// The learning state the AI tutor is given.
  TutorContext get tutorContext {
    final current = _requireProfile();
    return _contextBuilder.build(current, curriculum,
        currentLesson: currentLesson);
  }

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    profile = null;
    notifyListeners();

    try {
      curriculum = Curriculum(await _learningRepository.loadLessons());
      dialogues = await _learningRepository.loadDialogues();
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

  /// Starts the learner at the first lesson of the level they chose, so
  /// choosing A1 does not begin with A0 greetings.
  Future<void> completeOnboarding({
    required String language,
    required CefrLevel level,
    LearningGoal goal = LearningGoal.everyday,
  }) {
    final learner = LearningProfile.newLearner(
            nativeLanguage: language, currentLevel: level)
        .copyWith(goal: goal);
    return _commit(_withNextLesson(learner));
  }

  Future<void> updateProfile(LearningProfile updated) {
    // Moving the level moves the recommended lesson with it.
    final replan = updated.currentLevel != profile?.currentLevel ||
        updated.goal != profile?.goal ||
        !listEquals(updated.preferredTopics, profile?.preferredTopics);
    return _commit(replan ? _withNextLesson(updated) : updated);
  }

  Future<void> resetLearningProgress() async {
    final current = profile;
    if (current == null) return;
    await _commit(_withNextLesson(current.resetLearningProgress()));
  }

  LearningProfile _withNextLesson(LearningProfile learner) => learner.copyWith(
        currentLessonId: _path.nextLesson(learner, curriculum)?.id,
      );

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

  /// Applies a finished lesson.
  Future<SessionOutcome> completeLesson(
      Lesson lesson, List<ExerciseResult> results) async {
    final before = _requireProfile();
    final now = DateTime.now();
    final update =
        _tracker.completeLesson(before, lesson, curriculum, results, now: now);
    final scored = results.where((r) => !r.isRetry);
    await _commitWithRewards(
      update.profile,
      QuestEvent(lessons: 1, correct: scored.where((r) => r.isCorrect).length),
      now,
    );
    return (xpEarned: update.xpEarned, leveledUpTo: update.leveledUpTo);
  }

  /// Applies a practice or review session.
  Future<SessionOutcome> completePractice(List<ExerciseResult> results) async {
    final before = _requireProfile();
    final now = DateTime.now();
    final update =
        _tracker.completePractice(before, curriculum, results, now: now);
    final scored = results.where((r) => !r.isRetry);
    await _commitWithRewards(
      update.profile,
      QuestEvent(correct: scored.where((r) => r.isCorrect).length),
      now,
    );
    return (xpEarned: update.xpEarned, leveledUpTo: null);
  }

  /// Applies a finished flashcard session.
  Future<SessionOutcome> completeFlashcards(List<CardReview> reviews) async {
    final before = _requireProfile();
    final now = DateTime.now();
    final update = _tracker.completeFlashcards(before, reviews, now: now);
    await _commitWithRewards(
      update.profile,
      QuestEvent(
        cards: reviews.length,
        correct: reviews.where((r) => r.rating.recalled).length,
      ),
      now,
    );
    return (xpEarned: update.xpEarned, leveledUpTo: null);
  }

  /// Applies a finished mini-game.
  Future<SessionOutcome> completeGame(GameOutcome outcome) async {
    final before = _requireProfile();
    final now = DateTime.now();
    final update = _tracker.completeGame(before, outcome, now: now);
    await _commitWithRewards(
      update.profile,
      QuestEvent(games: 1, correct: outcome.correct),
      now,
    );
    return (xpEarned: update.xpEarned, leveledUpTo: null);
  }

  /// Changes what the learner is working towards. The recommended lesson
  /// follows the goal.
  Future<void> setGoal(LearningGoal goal) {
    final current = _requireProfile();
    if (current.goal == goal) return Future.value();
    return _commit(_withNextLesson(current.copyWith(goal: goal)));
  }

  /// Saves [next] together with quest progress and any badges it has earned.
  Future<void> _commitWithRewards(
    LearningProfile next,
    QuestEvent event,
    DateTime now,
  ) async {
    final reward = Achievements.apply(next, event, now);
    await _commit(reward.profile);
    lastReward = reward.hasNews ? reward : null;
    notifyListeners();
  }

  /// A practice session chosen from the learner's history, optionally limited
  /// to [skillIds]. Empty until the learner has started a lesson.
  List<Exercise> practiceExercises(
      {Iterable<String>? skillIds, int limit = 6}) {
    final current = profile;
    if (current == null) return const [];
    return _planner.buildSession(current, curriculum,
        now: DateTime.now(), skillIds: skillIds, limit: limit);
  }

  Future<CoachReply> correctGerman(String text) =>
      _aiRepository.correctGerman(text, tutorContext);

  Future<TutorReply> chat(String message) =>
      _aiRepository.chat(message, tutorContext);

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
