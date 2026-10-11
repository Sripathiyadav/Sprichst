import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../domain/repositories/learning_repository.dart';
import '../../shared/input_rules.dart';
import '../on_device/on_device_ai_repository.dart'
    show
        chatPrompt,
        correctionPrompt,
        parseCoachReply,
        parseTutorReply,
        systemPrompt;
import 'groq_settings.dart';

/// The AI tutor on Groq, called straight from the app with the learner's own
/// API key. There is no Sprichst server in between: the request goes from this
/// device to Groq, and what it costs counts against the learner's own free
/// quota.
///
/// Text and speech recognition only. Groq has no German voice, so speaking is
/// done by the on-device voices.
class GroqAIRepository implements AIRepository {
  GroqAIRepository({
    required this.settings,
    http.Client? client,
    this.baseUrl = defaultBaseUrl,
  }) : _client = client ?? http.Client();

  static const defaultBaseUrl = 'https://api.groq.com/openai/v1';
  static const transcriptionModel = 'whisper-large-v3-turbo';
  static const providerName = 'Groq';

  final GroqSettings settings;
  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 40);

  String _requireKey() {
    final key = settings.key;
    if (key == null) {
      throw const ProviderUnavailableException(
          providerName, ProviderProblem.noKey);
    }
    return key;
  }

  static const _jsonShapeChat =
      'Answer with one JSON object whose string fields are "corrected", "explanation", "reply" and "followUp".';
  static const _jsonShapeCorrection =
      'Answer with one JSON object with the boolean "correct" and the string fields "corrected", "explanation" and "followUp".';

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    final text = sanitizeText(message);
    final raw = await _complete([
      {
        'role': 'system',
        'content': '${systemPrompt(context)}\n$_jsonShapeChat',
      },
      {'role': 'user', 'content': chatPrompt(text, context.conversation)},
    ]);
    return parseTutorReply(raw, text);
  }

  @override
  Future<CoachReply> correctGerman(String text, TutorContext context) async {
    final clean = sanitizeText(text);
    final raw = await _complete([
      {
        'role': 'system',
        'content': '${systemPrompt(context)}\n$_jsonShapeCorrection',
      },
      {'role': 'user', 'content': correctionPrompt(clean)},
    ]);
    return parseCoachReply(raw, clean);
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
      AudioCapture audio, TutorContext context) async {
    final key = _requireKey();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/audio/transcriptions'))
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = transcriptionModel
      ..fields['language'] = 'de'
      ..fields['response_format'] = 'json'
      ..fields['temperature'] = '0'
      ..files.add(http.MultipartFile.fromBytes('file', audio.bytes,
          filename: audio.filename));

    final response = await _guard(() async => http.Response.fromStream(
        await _client.send(request).timeout(_timeout)));
    final data = _decode(response.body);
    final text = (data['text'] as String? ?? '').trim();
    return TranscriptionResult(text: text, language: 'de');
  }

  @override
  Future<SpeechAudio> synthesizeSpeech(String text, TutorContext context,
          {String? voice, int? speechRate}) =>
      throw UnsupportedError('Groq has no German voice; the phone speaks.');

  @override
  Future<VoiceList> listVoices() =>
      throw UnsupportedError('Groq has no German voice; the phone speaks.');

  /// Asks Groq whether [key] works. Null means it does.
  Future<ProviderProblem?> verifyKey(String key) async {
    try {
      await _guard(() => _client.get(Uri.parse('$baseUrl/models'),
          headers: {'Authorization': 'Bearer $key'}).timeout(_timeout));
      return null;
    } on ProviderUnavailableException catch (error) {
      // A reached-limit answer still proves the key is real.
      return error.problem == ProviderProblem.rateLimited
          ? null
          : error.problem;
    }
  }

  Future<String> _complete(List<Map<String, String>> messages) async {
    final key = _requireKey();
    final response = await _guard(() => _client
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': settings.model,
            'messages': messages,
            'temperature': 0.3,
            'max_tokens': 400,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(_timeout));

    try {
      final data = _decode(response.body);
      final content =
          ((data['choices'] as List).first as Map)['message']['content'];
      if (content is String && content.trim().isNotEmpty) return content;
    } catch (_) {}
    throw const ProviderUnavailableException(
        providerName, ProviderProblem.unavailable);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const ProviderUnavailableException(
          providerName, ProviderProblem.unavailable);
    }
  }

  /// Runs [send] and turns every way it can fail into a
  /// [ProviderUnavailableException]. Nothing here ever includes the key or the
  /// request, so a failure cannot leak either into a log or a message.
  Future<http.Response> _guard(Future<http.Response> Function() send) async {
    final http.Response response;
    try {
      response = await send();
    } on TimeoutException {
      throw const ProviderUnavailableException(
          providerName, ProviderProblem.offline);
    } on ProviderUnavailableException {
      rethrow;
    } catch (_) {
      throw const ProviderUnavailableException(
          providerName, ProviderProblem.offline);
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    if (code == 401 || code == 403) {
      throw const ProviderUnavailableException(
          providerName, ProviderProblem.invalidKey);
    }
    if (code == 429) {
      throw ProviderUnavailableException(
        providerName,
        ProviderProblem.rateLimited,
        retryAfter: retryAfterOf(response.headers, response.body),
      );
    }
    throw const ProviderUnavailableException(
        providerName, ProviderProblem.unavailable);
  }

  /// How long Groq asked us to wait: the `retry-after` header (seconds), else
  /// the "try again in 7m26.4s" it puts in the error message.
  static Duration? retryAfterOf(Map<String, String> headers, String body) {
    final header = int.tryParse(headers['retry-after'] ?? '');
    if (header != null && header > 0) return Duration(seconds: header);
    final match = RegExp(
            r'try again in\s*(?:(\d+)h)?\s*(?:(\d+)m(?!s))?\s*(?:([\d.]+)s)?',
            caseSensitive: false)
        .firstMatch(body);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = double.tryParse(match.group(3) ?? '') ?? 0;
    final total = Duration(
        hours: hours, minutes: minutes, milliseconds: (seconds * 1000).round());
    return total == Duration.zero ? null : total;
  }
}
