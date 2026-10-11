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
import 'cloud_ai_settings.dart';
import 'cloud_providers.dart';

/// The AI tutor on whichever platform the learner brought a key for (Groq,
/// Gemini, OpenAI, Claude, Grok, Mistral, DeepSeek, OpenRouter or any
/// OpenAI-compatible server), called straight from the app. There is no
/// Sprichst server in between: the request goes from this device to the
/// provider, and what it costs counts against the learner's own account.
///
/// Text, and speech recognition where the provider has it. No provider here
/// has a German voice the app uses, so speaking is done by the phone.
class CloudAIRepository implements AIRepository {
  CloudAIRepository({required this.settings, http.Client? client})
      : _client = client ?? http.Client();

  static const anthropicVersion = '2023-06-01';

  final CloudAISettings settings;
  final http.Client _client;

  static const _timeout = Duration(seconds: 40);
  static const _maxTokens = 400;

  CloudProvider get provider => settings.provider;
  bool get canTranscribe => provider.canTranscribe;

  ({CloudProvider provider, String base, String? key}) _target() {
    final p = provider;
    final base = settings.baseUrl;
    final key = settings.key;
    if (base == null || (key == null && !p.keyOptional)) {
      throw ProviderUnavailableException(p.name, ProviderProblem.noKey);
    }
    return (provider: p, base: base, key: key);
  }

  static const _jsonShapeChat =
      'Answer with one JSON object whose string fields are "corrected", "explanation", "reply" and "followUp". Answer with the JSON object only.';
  static const _jsonShapeCorrection =
      'Answer with one JSON object with the boolean "correct" and the string fields "corrected", "explanation" and "followUp". Answer with the JSON object only.';

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    final text = sanitizeText(message);
    final raw = await _complete(
      '${systemPrompt(context)}\n$_jsonShapeChat',
      chatPrompt(text, context.conversation),
    );
    return parseTutorReply(raw, text);
  }

  @override
  Future<CoachReply> correctGerman(String text, TutorContext context) async {
    final clean = sanitizeText(text);
    final raw = await _complete(
      '${systemPrompt(context)}\n$_jsonShapeCorrection',
      correctionPrompt(clean),
    );
    return parseCoachReply(raw, clean);
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
      AudioCapture audio, TutorContext context) async {
    final t = _target();
    final model = t.provider.transcriptionModel;
    if (model == null) {
      throw UnsupportedError('${t.provider.name} has no speech recognition.');
    }
    final request = http.MultipartRequest(
        'POST', Uri.parse('${t.base}/audio/transcriptions'))
      ..headers.addAll(_headers(t.provider, t.key, json: false))
      ..fields['model'] = model
      ..fields['language'] = 'de'
      ..fields['response_format'] = 'json'
      ..fields['temperature'] = '0'
      ..files.add(http.MultipartFile.fromBytes('file', audio.bytes,
          filename: audio.filename));

    final response = await _guard(
        t.provider,
        () async => http.Response.fromStream(
            await _client.send(request).timeout(_timeout)));
    final data = _decode(t.provider, response.body);
    final text = (data['text'] as String? ?? '').trim();
    return TranscriptionResult(text: text, language: 'de');
  }

  @override
  Future<SpeechAudio> synthesizeSpeech(String text, TutorContext context,
          {String? voice, int? speechRate}) =>
      throw UnsupportedError('Cloud providers do not speak; the phone does.');

  @override
  Future<VoiceList> listVoices() =>
      throw UnsupportedError('Cloud providers do not speak; the phone does.');

  /// Asks [provider] whether [key] works, by listing its models. Null means
  /// it does. [baseUrl] is needed for [CloudProvider.custom].
  Future<ProviderProblem?> verifyKey(CloudProvider provider, String? key,
      {String? baseUrl}) async {
    final base = provider.isCustom ? baseUrl : provider.baseUrl;
    if (base == null) return ProviderProblem.noKey;
    try {
      await _guard(
          provider,
          () => _client
              .get(Uri.parse('$base/models'),
                  headers: _headers(provider, key, json: false))
              .timeout(_timeout));
      return null;
    } on ProviderUnavailableException catch (error) {
      // A reached-limit answer still proves the key is real; a server without
      // a model list can still answer chats.
      return switch (error.problem) {
        ProviderProblem.rateLimited || ProviderProblem.unknownModel => null,
        final other => other,
      };
    }
  }

  Map<String, String> _headers(CloudProvider p, String? key,
      {required bool json}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (p.api == CloudApi.anthropic) ...{
        if (key != null) 'x-api-key': key,
        'anthropic-version': anthropicVersion,
        // Lets the web build call Anthropic straight from the browser; the
        // key is the learner's own, which is what this header is for.
        'anthropic-dangerous-direct-browser-access': 'true',
      } else if (key != null)
        'Authorization': 'Bearer $key',
    };
  }

  Future<String> _complete(String system, String user) async {
    final t = _target();
    final p = t.provider;
    final model = settings.model;

    final (path, body) = switch (p.api) {
      CloudApi.anthropic => (
          '/messages',
          {
            'model': model,
            'system': system,
            'messages': [
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.3,
            'max_tokens': _maxTokens,
          }
        ),
      CloudApi.openAi => (
          '/chat/completions',
          {
            'model': model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.3,
            p.maxTokensField: _maxTokens,
            if (p.jsonMode) 'response_format': {'type': 'json_object'},
          }
        ),
    };

    final response = await _guard(
        p,
        () => _client
            .post(Uri.parse('${t.base}$path'),
                headers: _headers(p, t.key, json: true), body: jsonEncode(body))
            .timeout(_timeout));

    try {
      final data = _decode(p, response.body);
      final content = switch (p.api) {
        CloudApi.anthropic => (data['content'] as List)
            .whereType<Map>()
            .where((block) => block['type'] == 'text')
            .map((block) => block['text'])
            .join(),
        CloudApi.openAi => ((data['choices'] as List).first as Map)['message']
            ['content'],
      };
      if (content is String && content.trim().isNotEmpty) return content;
    } catch (_) {}
    throw ProviderUnavailableException(p.name, ProviderProblem.unavailable);
  }

  Map<String, dynamic> _decode(CloudProvider p, String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ProviderUnavailableException(p.name, ProviderProblem.unavailable);
    }
  }

  /// Runs [send] and turns every way it can fail into a
  /// [ProviderUnavailableException]. Nothing here ever includes the key or the
  /// request, so a failure cannot leak either into a log or a message.
  Future<http.Response> _guard(
      CloudProvider p, Future<http.Response> Function() send) async {
    final http.Response response;
    try {
      response = await send();
    } on TimeoutException {
      throw ProviderUnavailableException(p.name, ProviderProblem.offline);
    } on ProviderUnavailableException {
      rethrow;
    } catch (_) {
      throw ProviderUnavailableException(p.name, ProviderProblem.offline);
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    final problem = problemOf(code, response.body);
    throw ProviderUnavailableException(
      p.name,
      problem,
      retryAfter: problem == ProviderProblem.rateLimited
          ? retryAfterOf(response.headers, response.body)
          : null,
    );
  }

  /// What an error answer means. Providers disagree on codes: Gemini says 400
  /// for a bad key, Anthropic 529 when overloaded, OpenAI 429 for both "slow
  /// down" and "out of credit"; the body tells them apart.
  static ProviderProblem problemOf(int code, String body) {
    final text = body.toLowerCase();
    if (code == 401 || code == 403) return ProviderProblem.invalidKey;
    if (code == 400 &&
        (text.contains('api key not valid') ||
            text.contains('api_key_invalid') ||
            text.contains('invalid api key') ||
            text.contains('invalid x-api-key'))) {
      return ProviderProblem.invalidKey;
    }
    if (code == 402 ||
        text.contains('insufficient_quota') ||
        text.contains('credit balance')) {
      return ProviderProblem.noCredit;
    }
    if (code == 429) return ProviderProblem.rateLimited;
    if (code == 404 ||
        ((code == 400 || code == 422) &&
            text.contains('model') &&
            (text.contains('not found') ||
                text.contains('does not exist') ||
                text.contains('not exist') ||
                text.contains('invalid model') ||
                text.contains('not supported')))) {
      return ProviderProblem.unknownModel;
    }
    return ProviderProblem.unavailable;
  }

  /// How long the provider asked us to wait: the `retry-after` header
  /// (seconds), else the "try again in 7m26.4s" Groq puts in its message.
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
