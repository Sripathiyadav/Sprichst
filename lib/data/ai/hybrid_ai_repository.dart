import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../domain/repositories/learning_repository.dart';
import '../on_device/model_manager.dart';
import '../on_device/on_device_ai_repository.dart';

/// Where one request should be answered, when the learner has said so.
enum AiRoute { phone }

const _routeKey = #sprichstAiRoute;

/// Runs [body] so that every AI request made inside it is answered on the
/// phone, whatever the learner's setting says. Used when the learner has just
/// been told the cloud is unavailable and chose "answer on this phone".
Future<T> runOnPhone<T>(Future<T> Function() body) =>
    runZoned(body, zoneValues: {_routeKey: AiRoute.phone});

/// Chooses where the tutor answers, following the learner's
/// [AIProviderPreference]:
///
/// * automatic: the phone first. Only for what is not downloaded does it use
///   the learner's own cloud key (or, for developers, the AI server).
/// * cloud: the learner's provider (Groq, Gemini, OpenAI…) first. If it cannot
///   answer (limit reached, offline, bad key) the learner is told and offered
///   the phone; nothing is sent anywhere else without their say-so.
/// * local: the phone only. Nothing leaves the device.
///
/// Speech recognition goes to the provider only if it has one; otherwise the
/// phone's Whisper hears the learner. Speaking is always the phone's (or the
/// developer server's, in a browser where models cannot run).
class HybridAIRepository implements AIRepository {
  HybridAIRepository({
    required this.onDevice,
    required this.server,
    required this.models,
    this.cloud,
    bool Function()? cloudAvailable,
    bool Function()? cloudCanTranscribe,
    String Function()? providerName,
    bool Function()? serverEnabled,
    AIProviderPreference Function()? preference,
  })  : preference = preference ?? _automatic,
        _cloudAvailable = cloudAvailable ?? (() => cloud != null),
        _cloudCanTranscribe = cloudCanTranscribe ?? (() => true),
        _providerName = providerName ?? (() => 'your AI provider'),
        _serverEnabled = serverEnabled ?? (() => true);

  static AIProviderPreference _automatic() => AIProviderPreference.automatic;

  final OnDeviceAIRepository onDevice;

  /// The developer AI server (`ai-server/`). Not part of the shipped path.
  final AIRepository server;

  /// The learner's own cloud account, when there is a key.
  final AIRepository? cloud;
  final ModelManager models;
  final bool Function() _cloudAvailable;
  final bool Function() _cloudCanTranscribe;
  final bool Function() _serverEnabled;

  /// The learner's choice. Set by the app once the profile is available; a
  /// provider cannot read it directly because the app controller itself depends
  /// on this repository.
  AIProviderPreference Function() preference;

  /// The chosen provider's name, for "add your key" messages.
  final String Function() _providerName;

  ProviderUnavailableException get _noKey =>
      ProviderUnavailableException(_providerName(), ProviderProblem.noKey);

  bool get _hasCloud => cloud != null && _cloudAvailable();

  /// Text, corrections and speech recognition. [hearing] marks speech
  /// recognition, which stays on the phone when the provider cannot do it.
  Future<T> _text<T>(Future<T> Function(AIRepository repo) call,
      {bool hearing = false}) async {
    await models.ensureLoaded();
    if (Zone.current[_routeKey] == AiRoute.phone) return call(onDevice);

    final pref = preference();

    // A browser cannot run models: the cloud is the only place to answer.
    if (!models.isSupported) return _cloud(call, hearing: hearing);

    // The provider cannot hear: the phone's Whisper does, whatever the mode.
    if (hearing && pref != AIProviderPreference.local && _hasCloud &&
        !_cloudCanTranscribe()) {
      return call(onDevice);
    }

    switch (pref) {
      case AIProviderPreference.local:
        return call(onDevice);
      case AIProviderPreference.cloud:
        if (!_hasCloud) throw _noKey;
        return call(cloud!); // a failure reaches the learner; no silent switch
      case AIProviderPreference.automatic:
        try {
          return await call(onDevice);
        } on ModelNotInstalledException {
          if (_hasCloud) return call(cloud!);
          if (_serverEnabled()) {
            try {
              return await call(server);
            } catch (_) {
              // offline, "download X" beats "server unreachable"
            }
          }
          rethrow;
        }
    }
  }

  Future<T> _cloud<T>(Future<T> Function(AIRepository repo) call,
      {bool hearing = false}) {
    final cloudCanHear = !hearing || _cloudCanTranscribe();
    if (_hasCloud && cloudCanHear) return call(cloud!);
    if (_serverEnabled()) return call(server);
    if (_hasCloud) throw HearingUnavailableException(_providerName());
    throw _noKey;
  }

  /// Speaking: the phone's voices; the developer server only where the phone
  /// cannot run them (a browser) or has not got the voice yet.
  Future<T> _speech<T>(Future<T> Function(AIRepository repo) call) async {
    await models.ensureLoaded();
    if (!models.isSupported) {
      if (_serverEnabled()) return call(server);
      throw const VoiceUnavailableException();
    }
    try {
      return await call(onDevice);
    } on ModelNotInstalledException {
      if (preference() != AIProviderPreference.local && _serverEnabled()) {
        try {
          return await call(server);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<CoachReply> correctGerman(String text, TutorContext context) =>
      _text((r) => r.correctGerman(text, context));

  @override
  Future<TutorReply> chat(String message, TutorContext context) =>
      _text((r) => r.chat(message, context));

  @override
  Future<TranscriptionResult> transcribeAudio(
          AudioCapture audio, TutorContext context) =>
      _text((r) => r.transcribeAudio(audio, context), hearing: true);

  @override
  Future<SpeechAudio> synthesizeSpeech(String text, TutorContext context,
          {String? voice, int? speechRate}) =>
      _speech((r) => r.synthesizeSpeech(text, context,
          voice: voice, speechRate: speechRate));

  @override
  Future<VoiceList> listVoices() async {
    await models.ensureLoaded();
    if (models.isSupported) return onDevice.listVoices();
    return _serverEnabled() ? server.listVoices() : VoiceList.offline;
  }

  /// Whether a developer server may be used at all in this build: debug builds
  /// and anyone who typed a server address themselves.
  static bool defaultServerEnabled({required bool hasCustomAddress}) =>
      kDebugMode || hasCustomAddress;
}
