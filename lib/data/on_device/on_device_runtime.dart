import 'model_catalogue.dart';

export 'on_device_runtime_stub.dart'
    if (dart.library.io) 'on_device_runtime_io.dart' show createOnDeviceRuntime;

/// One message for the on-device tutor model.
class TutorMessage {
  const TutorMessage.system(this.text) : role = 'system';
  const TutorMessage.user(this.text) : role = 'user';

  final String role;
  final String text;
}

/// Downloads cancel cooperatively: the runtime checks [cancelled] between
/// chunks and keeps what it has, so the next download resumes.
class DownloadCancel {
  bool cancelled = false;
}

class DownloadCancelled implements Exception {
  @override
  String toString() => 'Download cancelled.';
}

/// Everything that touches native code or the file system, so the rest of the
/// on-device AI can be tested with a fake and the web build stays compiling.
abstract class OnDeviceRuntime {
  /// False on platforms where models cannot run (the web).
  bool get isSupported;

  /// Total memory of this phone in MB, or null when unknown.
  Future<int?> deviceRamMb();

  /// Whether this device is a simulator or emulator.
  Future<bool> isSimulator();

  Future<bool> isInstalled(OnDeviceModel model);

  /// Downloads [model] (resuming a partial download) and unpacks archives.
  /// [onProgress] gets bytes received so far out of [OnDeviceModel.downloadBytes].
  Future<void> download(
    OnDeviceModel model, {
    required void Function(int received) onProgress,
    DownloadCancel? cancel,
  });

  Future<void> delete(OnDeviceModel model);

  /// Runs the tutor model on [messages] and returns its reply, constrained to
  /// [jsonSchema] so it is always parseable.
  Future<String> generateJson(
    OnDeviceModel model,
    List<TutorMessage> messages, {
    required Map<String, dynamic> jsonSchema,
    int maxTokens = 320,
  });

  /// German speech in a 16 kHz mono WAV file to text.
  Future<String> transcribe(OnDeviceModel model, List<int> wavBytes);

  /// [text] spoken by [voice] as WAV bytes. [lengthScale] > 1 is slower.
  Future<List<int>> synthesize(
    OnDeviceModel voice,
    String text, {
    double lengthScale = 1.0,
  });

  /// Frees the loaded tutor model (e.g. when switching models).
  Future<void> unloadTutor();
}
