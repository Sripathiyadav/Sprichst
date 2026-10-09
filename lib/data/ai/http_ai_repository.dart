import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';
import '../../shared/input_rules.dart';

class HttpAIRepository implements AIRepository {
  HttpAIRepository({
    required String baseUrl,
    http.Client? client,
    Future<String?> Function()? authToken,
  })  : _baseUrl = (() => baseUrl),
        _authToken = authToken,
        _client = client ?? http.Client();

  /// Reads the address on every request, so a change in settings takes effect
  /// straight away.
  HttpAIRepository.dynamic({
    required String Function() baseUrl,
    http.Client? client,
    Future<String?> Function()? authToken,
  })  : _baseUrl = baseUrl,
        _authToken = authToken,
        _client = client ?? http.Client();

  final String Function() _baseUrl;

  /// Supplies the learner's Firebase ID token. A server that requires sign-in
  /// (AUTH_REQUIRED=1) rejects calls without it; one that does not ignores it.
  final Future<String?> Function()? _authToken;

  Future<Map<String, String>> _headers({bool json = true}) async {
    // Failing to get a token (signed out, or no Firebase in this build) must
    // not stop a server that does not ask for one from answering.
    String? token;
    try {
      token = await _authToken?.call();
    } catch (_) {
      token = null;
    }
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

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
          headers: await _headers(),
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
          headers: await _headers(),
          body: jsonEncode({
            'message': message,
            'context': _encode(context),
            'conversation': _encodeConversation(context.conversation),
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
      ..headers.addAll(await _headers(json: false))
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
          headers: await _headers(),
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
    final response = await _client
        .get(Uri.parse('$baseUrl/v1/voices'),
            headers: await _headers(json: false))
        .timeout(_quick);
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

  /// The recent turns as the server accepts them: cleaned and clipped, empty
  /// ones dropped, and only the newest few.
  List<Map<String, String>> _encodeConversation(List<ConversationTurn> turns) {
    final encoded = [
      for (final turn in turns)
        if (sanitizeText(turn.text, maxLength: InputLimits.turn).isNotEmpty)
          {
            'role': turn.fromLearner ? 'learner' : 'tutor',
            'text': sanitizeText(turn.text, maxLength: InputLimits.turn),
          },
    ];
    return encoded.length > InputLimits.turns
        ? encoded.sublist(encoded.length - InputLimits.turns)
        : encoded;
  }

  /// The learner's context as the server accepts it: every text cleaned and
  /// within the server's limits (see [InputLimits]).
  Map<String, dynamic> _encode(TutorContext context) => {
        'level': context.level,
        'current_unit': context.unit == null
            ? null
            : sanitizeText(context.unit!, maxLength: InputLimits.medium),
        'current_lesson': context.lesson == null
            ? null
            : sanitizeText(context.lesson!, maxLength: InputLimits.medium),
        'weak_skills': sanitizeList(context.weakSkills,
            max: InputLimits.weakSkills, maxLength: InputLimits.short),
        'known_vocabulary': sanitizeList(context.knownVocabulary,
            max: InputLimits.vocabulary, maxLength: InputLimits.short),
        'recent_mistakes': sanitizeList(context.recentMistakes,
            max: InputLimits.mistakes, maxLength: InputLimits.medium),
      };
}
