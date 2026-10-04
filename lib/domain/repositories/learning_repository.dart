import '../models/learning_models.dart';

abstract class LearningRepository {
  Future<LearningProfile?> loadProfile();
  Future<void> saveProfile(LearningProfile profile);
  Future<List<Lesson>> loadLessons();
}

abstract class AIRepository {
  Future<CoachReply> correctGerman(
    String text,
    LearningProfile profile,
  );

  Future<TutorReply> chat(
    String message,
    LearningProfile profile,
  );

  Future<TranscriptionResult> transcribeAudio(
    AudioCapture audio,
    LearningProfile profile,
  );

  Future<List<int>> synthesizeSpeech(
    String text,
    LearningProfile profile,
  );
}
