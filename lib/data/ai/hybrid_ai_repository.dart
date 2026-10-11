import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';
import '../on_device/model_manager.dart';
import '../on_device/on_device_ai_repository.dart';

/// Chooses between the models on the phone and the optional AI server,
/// following the learner's [AIProviderPreference]:
///
/// - automatic: the phone first; the server only for what is not downloaded.
/// - server ([AIProviderPreference.groq]): the server first; the phone when
///   the server cannot be reached, so the coach still works offline.
/// - local: the phone only. Nothing leaves the device.
class HybridAIRepository implements AIRepository {
  HybridAIRepository({
    required this.onDevice,
    required this.server,
    required this.models,
    AIProviderPreference Function()? preference,
  }) : preference = preference ?? _automatic;

  static AIProviderPreference _automatic() => AIProviderPreference.automatic;

  final OnDeviceAIRepository onDevice;
  final AIRepository server;
  final ModelManager models;

  /// The learner's choice. Set by the app once the profile is available; a
  /// provider cannot read it directly because the app controller itself depends
  /// on this repository.
  AIProviderPreference Function() preference;

  Future<T> _run<T>(Future<T> Function(AIRepository repo) call) async {
    await models.ensureLoaded();
    final pref = preference();
    if (!models.isSupported) return call(server);

    if (pref == AIProviderPreference.groq) {
      try {
        return await call(server);
      } catch (_) {
        // Unreachable server: the phone answers instead (or says what to
        // download, which is the useful message when offline).
        return call(onDevice);
      }
    }

    try {
      return await call(onDevice);
    } on ModelNotInstalledException catch (missing) {
      if (pref == AIProviderPreference.local) rethrow;
      try {
        return await call(server);
      } catch (_) {
        throw missing; // offline, "download X" beats "server unreachable"
      }
    }
  }

  @override
  Future<CoachReply> correctGerman(String text, TutorContext context) =>
      _run((r) => r.correctGerman(text, context));

  @override
  Future<TutorReply> chat(String message, TutorContext context) =>
      _run((r) => r.chat(message, context));

  @override
  Future<TranscriptionResult> transcribeAudio(
          AudioCapture audio, TutorContext context) =>
      _run((r) => r.transcribeAudio(audio, context));

  @override
  Future<SpeechAudio> synthesizeSpeech(String text, TutorContext context,
          {String? voice, int? speechRate}) =>
      _run((r) => r.synthesizeSpeech(text, context,
          voice: voice, speechRate: speechRate));

  @override
  Future<VoiceList> listVoices() async {
    await models.ensureLoaded();
    return models.isSupported ? onDevice.listVoices() : server.listVoices();
  }
}
