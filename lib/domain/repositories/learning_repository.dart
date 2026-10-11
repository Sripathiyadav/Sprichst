import '../models/dialogue_models.dart';
import '../models/learning_models.dart';

abstract class LearningRepository {
  Future<LearningProfile?> loadProfile();
  Future<void> saveProfile(LearningProfile profile);
  Future<void> deleteLearningData();

  /// Sends any change that is still waiting to the cloud. Called when the app
  /// goes to the background or the learner signs out.
  Future<void> flush();
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

  /// Speaks [text]. [voice] is a voice id from [listVoices] (null for the
  /// gateway's default) and [speechRate] is in words per minute.
  Future<SpeechAudio> synthesizeSpeech(
    String text,
    TutorContext context, {
    String? voice,
    int? speechRate,
  });

  /// The voices the gateway can speak with.
  Future<VoiceList> listVoices();
}
