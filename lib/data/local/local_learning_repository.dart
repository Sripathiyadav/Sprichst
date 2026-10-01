import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

class LocalLearningRepository implements LearningRepository {
  static const _profileKey = 'sprichst_profile_v1';

  @override
  Future<LearningProfile?> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return LearningProfile(
      name: json['name'] as String,
      nativeLanguage: json['nativeLanguage'] as String,
      currentLevel: CefrLevel.values.byName(json['currentLevel'] as String),
      targetLevel: CefrLevel.c1,
      currentLessonId: json['currentLessonId'] as String,
      completedLessonIds: (json['completedLessonIds'] as List).cast<String>(),
      reviewItems: (json['reviewItems'] as List)
          .cast<Map>()
          .map((item) => ReviewItem(
                id: item['id'] as String,
                label: item['label'] as String,
                kind: item['kind'] as String,
                dueAt: DateTime.parse(item['dueAt'] as String),
                intervalDays: item['intervalDays'] as int? ?? 0,
              ))
          .toList(),
      scores: SkillScores(
        vocabulary: (json['vocabulary'] as num).toDouble(),
        grammar: (json['grammar'] as num).toDouble(),
      ),
      xp: json['xp'] as int,
      streak: json['streak'] as int,
      dailyGoalMinutes: json['dailyGoalMinutes'] as int,
    );
  }

  @override
  Future<void> saveProfile(LearningProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profileKey,
      jsonEncode({
        'name': profile.name,
        'nativeLanguage': profile.nativeLanguage,
        'currentLevel': profile.currentLevel.name,
        'currentLessonId': profile.currentLessonId,
        'completedLessonIds': profile.completedLessonIds,
        'reviewItems': profile.reviewItems
            .map((item) => {
                  'id': item.id,
                  'label': item.label,
                  'kind': item.kind,
                  'dueAt': item.dueAt.toIso8601String(),
                  'intervalDays': item.intervalDays,
                })
            .toList(),
        'vocabulary': profile.scores.vocabulary,
        'grammar': profile.scores.grammar,
        'xp': profile.xp,
        'streak': profile.streak,
        'dailyGoalMinutes': profile.dailyGoalMinutes,
      }),
    );
  }

  @override
  Future<List<Lesson>> loadLessons() async => _seedLessons;
}

const _seedLessons = <Lesson>[
  Lesson(
    id: 'pre_a1_greetings',
    level: CefrLevel.preA1,
    unit: 'First steps',
    title: 'Greetings',
    durationMinutes: 8,
    objective: 'Greet someone and say goodbye politely.',
    introduction:
        'German greetings change slightly with the time of day. Start with these everyday essentials.',
    examples: [
      'Hallo! — Hello!',
      'Guten Morgen! — Good morning!',
      'Tschüss! — Bye!'
    ],
    exercises: [
      Exercise(
        id: 'greeting_1',
        prompt: 'Choose the German word for “Thank you”.',
        options: ['Bitte', 'Danke', 'Tschüss'],
        answer: 'Danke',
        explanation:
            'Danke means “thank you”. Bitte can mean “please” or “you’re welcome”.',
      ),
      Exercise(
        id: 'greeting_2',
        prompt: 'What would you say when leaving a friend?',
        options: ['Guten Abend', 'Tschüss', 'Wie heißt du?'],
        answer: 'Tschüss',
        explanation: 'Tschüss is an informal, friendly goodbye.',
      ),
    ],
  ),
  Lesson(
    id: 'pre_a1_introductions',
    level: CefrLevel.preA1,
    unit: 'First steps',
    title: 'Introduce yourself',
    durationMinutes: 10,
    objective: 'Say your name and ask someone else’s name.',
    introduction: 'Use heißen to talk about names. With ich, it becomes heiße.',
    examples: [
      'Ich heiße Sam. — My name is Sam.',
      'Wie heißt du? — What is your name?',
      'Ich komme aus Indien. — I come from India.'
    ],
    exercises: [
      Exercise(
        id: 'intro_1',
        prompt: 'Complete: “Ich ___ Ana.”',
        options: ['heiße', 'heißt', 'heißen'],
        answer: 'heiße',
        explanation: 'With ich, heißen changes to heiße.',
      ),
      Exercise(
        id: 'intro_2',
        prompt: 'Choose: “What is your name?”',
        options: ['Wie heißt du?', 'Wo wohnst du?', 'Wie geht es dir?'],
        answer: 'Wie heißt du?',
        explanation: 'Wie heißt du? asks someone’s name informally.',
      ),
    ],
  ),
  Lesson(
    id: 'a1_articles',
    level: CefrLevel.a1,
    unit: 'Daily life',
    title: 'Definite articles',
    durationMinutes: 12,
    objective: 'Recognize der, die and das with common nouns.',
    introduction:
        'Every German noun has a grammatical gender. Learn the article together with the noun.',
    examples: [
      'der Tisch — the table',
      'die Lampe — the lamp',
      'das Kind — the child'
    ],
    exercises: [
      Exercise(
        id: 'article_1',
        prompt: 'Choose the correct article: ___ Tisch',
        options: ['der', 'die', 'das'],
        answer: 'der',
        explanation: 'Tisch is masculine: der Tisch.',
      ),
      Exercise(
        id: 'article_2',
        prompt: 'Choose the correct article: ___ Kind',
        options: ['der', 'die', 'das'],
        answer: 'das',
        explanation: 'Kind is neuter: das Kind.',
      ),
    ],
  ),
];
