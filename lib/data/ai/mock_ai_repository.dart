import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

class MockAIRepository implements AIRepository {
  @override
  Future<CoachReply> correctGerman(
    String text,
    LearningProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final normalized = text.trim();

    if (normalized.isEmpty) {
      return const CoachReply(
        original: '',
        corrected: '',
        explanation: 'Write a German sentence and I will help you correct it.',
        followUp: 'Try: Ich lerne Deutsch.',
        wasCorrect: true,
      );
    }

    if (normalized.contains('habe gegangen')) {
      return CoachReply(
        original: normalized,
        corrected: normalized.replaceFirst('habe gegangen', 'bin gegangen'),
        explanation:
            'The verb "gehen" normally uses "sein" in the perfect tense.',
        followUp: 'Can you make another sentence with "gehen"?',
        wasCorrect: false,
      );
    }

    if (normalized.contains('ich bin')) {
      return CoachReply(
        original: normalized,
        corrected: normalized,
        explanation: 'Good job. This sentence looks correct.',
        followUp: 'Can you tell me where you went yesterday?',
        wasCorrect: true,
      );
    }

    return CoachReply(
      original: normalized,
      corrected: normalized,
      explanation:
          'Your sentence looks reasonable. We can make the explanation more detailed once the AI tutor is connected.',
      followUp: 'Tell me something else in German.',
      wasCorrect: true,
    );
  }

  @override
  Future<TutorReply> chat(
    String message,
    LearningProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const TutorReply(
      reply: 'Sehr gut! Erzähl mir mehr auf Deutsch.',
      followUp: 'Was hast du heute gemacht?',
    );
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
    AudioCapture audio,
    LearningProfile profile,
  ) {
    throw UnsupportedError('Voice transcription requires the local AI gateway.');
  }

  @override
  Future<List<int>> synthesizeSpeech(
    String text,
    LearningProfile profile,
  ) {
    throw UnsupportedError('Speech playback requires the local AI gateway.');
  }
}
