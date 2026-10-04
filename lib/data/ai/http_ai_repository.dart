import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

class HttpAIRepository implements AIRepository {
  HttpAIRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<CoachReply> correctGerman(
    String text,
    LearningProfile profile,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/correct'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': text,
        'context': _buildContext(profile),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'AI server returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return CoachReply(
      original: data['original'] as String? ?? text,
      corrected: data['corrected'] as String? ?? text,
      explanation: data['explanation'] as String? ?? '',
      followUp: data['followUp'] as String? ?? '',
      wasCorrect: data['correct'] as bool? ?? false,
    );
  }

  @override
  Future<TutorReply> chat(
    String message,
    LearningProfile profile,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
        'context': _buildContext(profile),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'AI server returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return TutorReply(
      reply: data['reply'] as String? ?? '',
      correction: data['correction'] as String?,
      explanation: data['explanation'] as String?,
      followUp: data['followUp'] as String? ?? '',
    );
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
    AudioCapture audio,
    LearningProfile profile,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/transcribe'),
    )
      ..fields['context'] = jsonEncode(_buildContext(profile))
      ..files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audio.bytes,
          filename: audio.filename,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return TranscriptionResult(
      text: data['text'] as String? ?? '',
      language: data['language'] as String? ?? 'de',
    );
  }

  @override
  Future<List<int>> synthesizeSpeech(
    String text,
    LearningProfile profile,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/speak'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': text,
        'context': _buildContext(profile),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    return response.bodyBytes;
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return data['detail'] as String? ??
          'The local AI service returned an error.';
    } catch (_) {
      return 'The local AI service returned ${response.statusCode}.';
    }
  }

  Map<String, dynamic> _buildContext(LearningProfile profile) {
    return {
      'level': profile.currentLevel.label,
      'current_unit': null,
      'current_lesson': profile.currentLessonId,
      'weak_skills': _weakSkills(profile),
      'known_vocabulary': <String>[],
      'recent_mistakes': <String>[],
    };
  }

  List<String> _weakSkills(LearningProfile profile) {
    final entries = profile.scores.entries.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return entries.take(2).map((entry) => entry.key).toList();
  }
}
