import '../models/dialogue_models.dart';
import '../models/learning_models.dart';

abstract class LearningRepository {
  Future<LearningProfile?> loadProfile();
  Future<void> saveProfile(LearningProfile profile);
  Future<void> deleteLearningData();
  Future<List<Lesson>> loadLessons();
  Future<List<Dialogue>> loadDialogues();
}

abstract class AIRepository {
  Future<CoachReply> correctGerman(
    String text,
    TutorContext context,
  );

  Future<TutorReply> chat(
    String message,
    TutorContext context,
  );

  Future<TranscriptionResult> transcribeAudio(
    AudioCapture audio,
    TutorContext context,
  );

  Future<List<int>> synthesizeSpeech(
    String text,
    TutorContext context,
  );
}
