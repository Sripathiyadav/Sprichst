import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai/ai_server_settings.dart';
import '../data/ai/groq_ai_repository.dart';
import '../data/ai/groq_settings.dart';
import '../data/ai/http_ai_repository.dart';
import '../data/ai/hybrid_ai_repository.dart';
import '../data/on_device/model_manager.dart';
import '../data/on_device/on_device_ai_repository.dart';
import '../data/on_device/on_device_runtime.dart';
import '../data/firestore/firestore_learning_repository.dart';
import '../domain/games/game_models.dart';
import '../domain/games/word_pool.dart';
import '../domain/games/dialogue_game.dart';
import '../domain/learning/achievements.dart';
import '../domain/learning/conversation_guard.dart';
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
import '../features/auth/auth_view_model.dart';
import '../shared/input_rules.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return FirestoreLearningRepository();
});

/// Where the AI gateway is, remembered on this device.
final aiServerSettingsProvider = ChangeNotifierProvider<AiServerSettings>(
    (ref) => AiServerSettings()..load());

final onDeviceRuntimeProvider =
    Provider<OnDeviceRuntime>((ref) => createOnDeviceRuntime());

/// Models downloaded to this phone, and downloads in progress.
final modelManagerProvider = ChangeNotifierProvider<ModelManager>(
    (ref) => ModelManager(ref.watch(onDeviceRuntimeProvider)));

/// The learner's own Groq key and model. Stored on this device only.
final groqSettingsProvider =
    ChangeNotifierProvider<GroqSettings>((ref) => GroqSettings()..load());

/// The tutor runs on the phone or on the learner's own Groq account, as they
/// choose (see [HybridAIRepository]). There is no Sprichst AI server in the
/// shipped path; the developer gateway is only used by debug builds and by
/// anyone who typed an address for it.
final Provider<AIRepository> aiRepositoryProvider =
    Provider<AIRepository>((ref) {
  final models = ref.read(modelManagerProvider);
  final groqSettings = ref.read(groqSettingsProvider);
  return HybridAIRepository(
    onDevice: OnDeviceAIRepository(models),
    server: HttpAIRepository.dynamic(
      baseUrl: () => ref.read(aiServerSettingsProvider).url,
      authToken: () => ref.read(authRepositoryProvider).idToken(),
    ),
    groq: GroqAIRepository(settings: groqSettings),
    groqAvailable: () => ref.read(groqSettingsProvider).hasKey,
    serverEnabled: () => HybridAIRepository.defaultServerEnabled(
        hasCustomAddress: ref.read(aiServerSettingsProvider).isCustom),
    models: models,
  );
});

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final ai = ref.watch(aiRepositoryProvider);
  final controller = AppController(
    learningRepository: ref.watch(learningRepositoryProvider),
    aiRepository: ai,
  );
  // The repository follows the learner's setting. It is wired here, in one
  // direction only: reading the controller from inside the repository's own
  // provider is a circular dependency that fails every coach request.
  if (ai is HybridAIRepository) {
    ai.preference = () =>
        controller.profile?.aiProviderPreference ??
        AIProviderPreference.automatic;
  }
  return controller;
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
  final ConversationGuard _guard = const ConversationGuard();

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
    _conversation.clear();
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
    _conversation.clear();
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

  /// Speaks [text] with the learner's chosen voice and speed. [voice] overrides
  /// the saved voice (used to preview voices in settings).
  Future<SpeechAudio> speak(String text, {String? voice}) {
    final current = _requireProfile();
    final clean = sanitizeText(text);
    if (clean.isEmpty) throw ArgumentError('There is nothing to say.');
    return _aiRepository.synthesizeSpeech(
      clean,
      tutorContext,
      voice: voice ?? current.voice,
      speechRate: current.speechRate,
    );
  }

  /// The voices the gateway offers, or the built-in list when it is offline.
  Future<VoiceList> loadVoices() async {
    try {
      return await _aiRepository.listVoices();
    } catch (_) {
      return VoiceList.offline;
    }
  }

  /// Transcribes a recorded clip.
  Future<String> transcribe(AudioCapture audio) async =>
      (await _aiRepository.transcribeAudio(audio, tutorContext)).text;

  Future<CoachReply> correctGerman(String text) =>
      _aiRepository.correctGerman(_nonEmpty(text), tutorContext);

  /// Sends profile changes that are still waiting to the cloud (they are
  /// gathered for a few seconds to save writes). Never throws: whatever cannot
  /// be sent stays on the device and is pushed next time.
  Future<void> flushPendingChanges() async {
    try {
      await _learningRepository.flush();
    } catch (_) {}
  }

  /// The recent turns of the coach conversation, shared by text and voice
  /// mode, so the tutor builds on what was said instead of starting over.
  final List<ConversationTurn> _conversation = [];

  List<ConversationTurn> get conversation => List.unmodifiable(_conversation);

  /// Runs [action] with every AI request answered on the phone. Offered to the
  /// learner after the cloud could not answer; never done on its own.
  Future<T> onThePhone<T>(Future<T> Function() action) => runOnPhone(action);

  /// Forgets the conversation so far; the next message starts a new one.
  void startNewConversation() => _conversation.clear();

  Future<TutorReply> chat(String message) async {
    final text = _nonEmpty(message);
    final context = tutorContext;
    final earlier = List<ConversationTurn>.of(_conversation);
    final raw = await _aiRepository.chat(
      text,
      context.withConversation(earlier),
    );
    // What the learner just said counts too: if it answers the question the
    // model is about to ask (their name, say), asking it would be silly.
    final reply = _guard.freshen(
        raw, [...earlier, ConversationTurn.learner(text)],
        level: context.level);
    _remember(ConversationTurn.learner(text));
    _remember(ConversationTurn.tutor(
        [reply.reply, reply.followUp].where((p) => p.isNotEmpty).join(' ')));
    return reply;
  }

  void _remember(ConversationTurn turn) {
    _conversation.add(turn);
    while (_conversation.length > ConversationGuard.maxTurns) {
      _conversation.removeAt(0);
    }
  }

  /// Text for the tutor, cleaned and within the server's limit.
  String _nonEmpty(String text) {
    final clean = sanitizeText(text);
    if (clean.isEmpty) throw ArgumentError('Write something first.');
    return clean;
  }

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
