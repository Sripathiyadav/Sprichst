import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

/// A safe, deterministic development fallback. Swap it for the API-backed
/// repository after starting ai-server and configuring a reachable gateway.
class MockAIRepository implements AIRepository {
  @override
  Future<CoachReply> correctGerman(String text, LearningProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final input = text.trim();
    final normalized = input.toLowerCase();
    if (normalized.contains('ich gehen')) {
      return const CoachReply(
        corrected: 'Ich gehe morgen zur Arbeit.',
        explanation:
            'With ich, gehen becomes gehe. “Zur Arbeit” is the natural phrase for going to work.',
        followUp: 'Was machst du morgen?',
        wasCorrect: false,
      );
    }
    if (normalized.contains('ich bin') || normalized.contains('ich heiße')) {
      return CoachReply(
        corrected: input,
        explanation:
            'That sentence looks good for ${profile.currentLevel.label}. Nice work.',
        followUp: 'Can you add one more detail?',
        wasCorrect: true,
      );
    }
    return CoachReply(
      corrected: input,
      explanation:
          'The local demo coach cannot verify every sentence yet. Connect the AI gateway for a curriculum-aware correction.',
      followUp: 'Try: “Ich gehe morgen zur Arbeit.”',
      wasCorrect: true,
    );
  }
}
