import 'model_catalogue.dart';
import 'on_device_runtime.dart';

OnDeviceRuntime createOnDeviceRuntime() => _UnsupportedRuntime();

/// The web cannot run the native models; the app uses the AI server there.
class _UnsupportedRuntime implements OnDeviceRuntime {
  @override
  bool get isSupported => false;

  @override
  Future<int?> deviceRamMb() async => null;

  @override
  Future<bool> isSimulator() async => false;

  @override
  Future<bool> isInstalled(OnDeviceModel model) async => false;

  Never _unsupported() =>
      throw UnsupportedError('On-device AI is not available in the browser.');

  @override
  Future<void> download(OnDeviceModel model,
          {required void Function(int received) onProgress,
          DownloadCancel? cancel}) async =>
      _unsupported();

  @override
  Future<void> delete(OnDeviceModel model) async {}

  @override
  Future<String> generateJson(OnDeviceModel model, List<TutorMessage> messages,
          {required Map<String, dynamic> jsonSchema,
          int maxTokens = 320}) async =>
      _unsupported();

  @override
  Future<String> transcribe(OnDeviceModel model, List<int> wavBytes) async =>
      _unsupported();

  @override
  Future<List<int>> synthesize(OnDeviceModel voice, String text,
          {double lengthScale = 1.0}) async =>
      _unsupported();

  @override
  Future<void> unloadTutor() async {}
}
