import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';

void main() {
  test('reset learning progress preserves account preferences', () {
    final profile = LearningProfile.newLearner(
      nativeLanguage: 'English',
      currentLevel: CefrLevel.a1,
    ).copyWith(
      name: 'Sam',
      lessonProgress: const {
        'pre_a1_greetings': LessonProgress(status: LessonStatus.completed),
      },
      skillStats: const {'greetings': SkillStat(attempts: 3, correct: 1)},
      recentMistakes: const ['Greetings: Choose the word'],
      lastStudyDate: DateTime(2026, 10, 4),
      reviewItems: [
        ReviewItem(
          id: 'greetings',
          label: 'Greetings',
          kind: 'Lesson recall',
          dueAt: DateTime(2026, 10, 5),
        ),
      ],
      scores: const SkillScores(vocabulary: .8, grammar: .7),
      xp: 140,
      streak: 6,
      dailyGoalMinutes: 20,
      appearancePreference: AppearancePreference.dark,
      aiProviderPreference: AIProviderPreference.local,
      preferredTopics: const ['Travel'],
      focusSkills: const ['Grammar'],
    );

    final reset = profile.resetLearningProgress();

    expect(reset.name, 'Sam');
    expect(reset.currentLevel, CefrLevel.a1);
    expect(reset.dailyGoalMinutes, 20);
    expect(reset.appearancePreference, AppearancePreference.dark);
    expect(reset.aiProviderPreference, AIProviderPreference.local);
    expect(reset.preferredTopics, ['Travel']);
    expect(reset.focusSkills, ['Grammar']);
    expect(reset.lessonProgress, isEmpty);
    expect(reset.skillStats, isEmpty);
    expect(reset.recentMistakes, isEmpty);
    expect(reset.lastStudyDate, isNull);
    expect(reset.reviewItems, isEmpty);
    expect(reset.currentLessonId, 'pre_a1_greetings');
    expect(reset.xp, 0);
    expect(reset.streak, 0);
    expect(reset.scores.vocabulary, .25);
  });
}
