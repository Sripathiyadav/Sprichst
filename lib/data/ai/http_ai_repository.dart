import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';

class HttpAIRepository implements AIRepository {
  HttpAIRepository({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = (() => baseUrl),
        _client = client ?? http.Client();

  /// Reads the address on every request, so a change in settings takes effect
  /// straight away.
  HttpAIRepository.dynamic({
    required String Function() baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final String Function() _baseUrl;
  final http.Client _client;

  /// How long a request may take before it counts as unreachable. Generating a
  /// reply is slow on a small local model; everything else is quick.
  static const _slow = Duration(seconds: 90);
  static const _quick = Duration(seconds: 15);

  String get baseUrl => _baseUrl();

  @override
  Future<CoachReply> correctGerman(
    String text,
    TutorContext context,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/correct'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': text,
            'context': _encode(context),
          }),
        )
        .timeout(_slow);

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
    TutorContext context,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/chat'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': message,
            'context': _encode(context),
          }),
        )
        .timeout(_slow);

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
    TutorContext context,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/transcribe'),
    )
      ..fields['context'] = jsonEncode(_encode(context))
      ..files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audio.bytes,
          filename: audio.filename,
        ),
      );

    final streamed = await request.send().timeout(_slow);
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
  Future<SpeechAudio> synthesizeSpeech(
    String text,
    TutorContext context, {
    String? voice,
    int? speechRate,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/speak'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': text,
            if (voice != null) 'voice': voice,
            if (speechRate != null) 'rate': speechRate,
            'context': _encode(context),
          }),
        )
        .timeout(_slow);

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    return SpeechAudio(
      response.bodyBytes,
      voiceUsed: response.headers['x-voice-used'],
      usedFallback: response.headers['x-voice-fallback'] == 'true',
    );
  }

  @override
  Future<VoiceList> listVoices() async {
    final response =
        await _client.get(Uri.parse('$baseUrl/v1/voices')).timeout(_quick);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }
    return VoiceList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
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

  Map<String, dynamic> _encode(TutorContext context) => {
        'level': context.level,
        'current_unit': context.unit,
        'current_lesson': context.lesson,
        'weak_skills': context.weakSkills,
        'known_vocabulary': context.knownVocabulary,
        'recent_mistakes': context.recentMistakes,
      };
}
