import 'package:sprichst/data/on_device/model_catalogue.dart';
import 'package:sprichst/data/on_device/on_device_runtime.dart';

/// Records what the app asks of the native layer and answers from canned data.
class FakeRuntime implements OnDeviceRuntime {
  FakeRuntime({this.ram = 6144, Set<String>? installed})
      : installed = installed ?? {};

  final int? ram;
  final Set<String> installed;
  String reply = '{}';
  bool simulator = false;
  Object? downloadError;
  final List<String> calls = [];

  @override
  bool get isSupported => true;
  @override
  Future<int?> deviceRamMb() async => ram;
  @override
  Future<bool> isSimulator() async => simulator;
  @override
  Future<bool> isInstalled(OnDeviceModel model) async =>
      installed.contains(model.id);

  @override
  Future<void> download(OnDeviceModel model,
      {required void Function(int received) onProgress,
      DownloadCancel? cancel}) async {
    onProgress(model.downloadBytes ~/ 2);
    if (downloadError != null) throw downloadError!;
    if (cancel?.cancelled ?? false) throw DownloadCancelled();
    onProgress(model.downloadBytes);
    installed.add(model.id);
  }

  @override
  Future<void> delete(OnDeviceModel model) async => installed.remove(model.id);

  @override
  Future<String> generateJson(OnDeviceModel model, List<TutorMessage> messages,
      {required Map<String, dynamic> jsonSchema, int maxTokens = 320}) async {
    calls.add('generate:${model.id}');
    return reply;
  }

  @override
  Future<String> transcribe(OnDeviceModel model, List<int> wavBytes) async {
    calls.add('transcribe:${model.id}');
    return 'Ich habe ein Hund';
  }

  @override
  Future<List<int>> synthesize(OnDeviceModel voice, String text,
      {double lengthScale = 1.0}) async {
    calls.add('speak:${voice.id}:$lengthScale');
    return [1, 2, 3];
  }

  @override
  Future<void> unloadTutor() async {}
}
