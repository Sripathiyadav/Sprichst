import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local/local_learning_repository.dart';

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

class FirestoreLearningRepository implements LearningRepository {
  FirestoreLearningRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    LocalLearningRepository? localRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _localRepository = localRepository ?? LocalLearningRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final LocalLearningRepository _localRepository;
  DocumentReference<Map<String, dynamic>> get _profileDocument {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('User must be signed in to access learning data.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning')
        .doc('profile');
  }

  @override
  Future<LearningProfile?> loadProfile() async {
    final snapshot = await _profileDocument.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return _profileFromMap(snapshot.data()!);
  }

  @override
  Future<void> saveProfile(LearningProfile profile) async {
    await _profileDocument.set(
      _profileToMap(profile),
      SetOptions(merge: true),
    );
  }

  @override
  Future<List<Lesson>> loadLessons() {
    return _localRepository.loadLessons();
  }

  Map<String, dynamic> _profileToMap(LearningProfile profile) {
    return {
      'name': profile.name,
      'nativeLanguage': profile.nativeLanguage,
      'currentLevel': profile.currentLevel.name,
      'targetLevel': profile.targetLevel.name,
      'currentLessonId': profile.currentLessonId,
      'completedLessonIds': profile.completedLessonIds,
      'reviewItems': profile.reviewItems
          .map(
            (item) => {
              'id': item.id,
              'label': item.label,
              'kind': item.kind,
              'dueAt': Timestamp.fromDate(item.dueAt),
              'intervalDays': item.intervalDays,
            },
          )
          .toList(),
      'scores': {
        'vocabulary': profile.scores.vocabulary,
        'grammar': profile.scores.grammar,
        'reading': profile.scores.reading,
        'listening': profile.scores.listening,
        'writing': profile.scores.writing,
        'speaking': profile.scores.speaking,
      },
      'xp': profile.xp,
      'streak': profile.streak,
      'dailyGoalMinutes': profile.dailyGoalMinutes,
    };
  }

  LearningProfile _profileFromMap(Map<String, dynamic> data) {
    final scores = Map<String, dynamic>.from(
      data['scores'] as Map? ?? {},
    );

    final reviewItems = (data['reviewItems'] as List? ?? []).map(
      (item) {
        final map = Map<String, dynamic>.from(item as Map);

        return ReviewItem(
          id: map['id'] as String,
          label: map['label'] as String,
          kind: map['kind'] as String,
          dueAt: (map['dueAt'] as Timestamp).toDate(),
          intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
        );
      },
    ).toList();

    return LearningProfile(
      name: data['name'] as String? ?? 'Learner',
      nativeLanguage: data['nativeLanguage'] as String? ?? 'English',
      currentLevel: _cefrLevelFromString(
        data['currentLevel'] as String?,
      ),
      targetLevel: _cefrLevelFromString(
        data['targetLevel'] as String?,
        fallback: CefrLevel.c1,
      ),
      currentLessonId: data['currentLessonId'] as String? ?? 'pre_a1_greetings',
      completedLessonIds:
          List<String>.from(data['completedLessonIds'] as List? ?? []),
      reviewItems: reviewItems,
      scores: SkillScores(
        vocabulary: (scores['vocabulary'] as num?)?.toDouble() ?? .25,
        grammar: (scores['grammar'] as num?)?.toDouble() ?? .20,
        reading: (scores['reading'] as num?)?.toDouble() ?? .20,
        listening: (scores['listening'] as num?)?.toDouble() ?? .10,
        writing: (scores['writing'] as num?)?.toDouble() ?? .10,
        speaking: (scores['speaking'] as num?)?.toDouble() ?? .10,
      ),
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (data['dailyGoalMinutes'] as num?)?.toInt() ?? 15,
    );
  }

  CefrLevel _cefrLevelFromString(
    String? value, {
    CefrLevel fallback = CefrLevel.preA1,
  }) {
    for (final level in CefrLevel.values) {
      if (level.name == value) {
        return level;
      }
    }

    return fallback;
  }
}
