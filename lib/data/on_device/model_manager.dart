import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_catalogue.dart';
import 'on_device_runtime.dart';

/// Which on-device models are installed and chosen, and downloads in flight.
///
/// Choices are saved on this device, not the account: a model downloaded on
/// one phone is not on the learner's other devices.
class ModelManager extends ChangeNotifier {
  ModelManager(this.runtime, {Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final OnDeviceRuntime runtime;
  final Future<SharedPreferences> Function() _prefs;

  static const _tutorKey = 'onDevice.tutor';
  static const _speechKey = 'onDevice.speechRecognition';

  int? ramMb;
  bool isSimulator = false;
  bool _ready = false;
  Future<void>? _init;

  final Set<String> _installed = {};
  final Map<String, int> _progress = {};
  final Map<String, DownloadCancel> _cancels = {};
  final Map<String, String> errors = {};
  String? _tutorId;
  String? _speechId;

  bool get isSupported => runtime.isSupported;
  bool get isReady => _ready;

  /// Loads RAM, saved choices and what is on disk. Safe to call repeatedly.
  Future<void> ensureLoaded() => _init ??= _load();

  Future<void> _load() async {
    await Future<void>.value(); // never notify during the caller's build
    if (!runtime.isSupported) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      ramMb = await runtime.deviceRamMb();
      isSimulator = await runtime.isSimulator();
      final prefs = await _prefs();
      _tutorId = prefs.getString(_tutorKey);
      _speechId = prefs.getString(_speechKey);
      for (final model in [
        ...tutorModels,
        ...speechRecognitionModels,
        ...voiceModels.values,
      ]) {
        if (await runtime.isInstalled(model)) _installed.add(model.id);
      }
    } catch (_) {
      // No storage or plugins (e.g. tests): treat as nothing installed.
    }
    _ready = true;
    notifyListeners();
  }

  /// Simulators report the host's memory but run models on the CPU only, so
  /// they get at most the Balanced model or every answer takes minutes.
  OnDeviceModel get recommendedTutorModel {
    final pick = recommendedTutor(ramMb);
    final cap = tutorModels[1];
    return isSimulator && tutorModels.indexOf(pick) > tutorModels.indexOf(cap)
        ? cap
        : pick;
  }

  OnDeviceModel get recommendedSpeechModel =>
      recommendedSpeechRecognition(ramMb);

  bool isInstalled(String id) => _installed.contains(id);
  bool isDownloading(String id) => _progress.containsKey(id);

  /// 0..1 while downloading, else null.
  double? progressOf(String id) {
    final received = _progress[id];
    final model = findModel(id);
    if (received == null || model == null) return null;
    return (received / model.downloadBytes).clamp(0.0, 1.0);
  }

  /// The tutor the learner picked, else the recommendation.
  OnDeviceModel get selectedTutor =>
      findModel(_tutorId ?? '') ?? recommendedTutorModel;
  OnDeviceModel get selectedSpeechModel =>
      findModel(_speechId ?? '') ?? recommendedSpeechModel;

  /// The tutor to run now: the chosen one if installed, else any installed.
  OnDeviceModel? get activeTutor => _active(selectedTutor, tutorModels);
  OnDeviceModel? get activeSpeechModel =>
      _active(selectedSpeechModel, speechRecognitionModels);

  OnDeviceModel? _active(OnDeviceModel chosen, List<OnDeviceModel> all) {
    if (isInstalled(chosen.id)) return chosen;
    for (final m in all.reversed) {
      if (isInstalled(m.id)) return m;
    }
    return null;
  }

  /// The installed voice to speak with: [wanted] if it is here, else the
  /// default, else any installed voice.
  OnDeviceModel? voiceFor(String? wanted) {
    for (final id in [wanted, 'de_DE-thorsten-medium']) {
      if (id != null && isInstalled(id)) return voiceModels[id];
    }
    for (final v in voiceModels.values) {
      if (isInstalled(v.id)) return v;
    }
    return null;
  }

  Future<void> selectTutor(String id) async {
    _tutorId = id;
    (await _prefs()).setString(_tutorKey, id);
    notifyListeners();
  }

  Future<void> selectSpeechModel(String id) async {
    _speechId = id;
    (await _prefs()).setString(_speechKey, id);
    notifyListeners();
  }

  /// Downloads [id]. Errors are kept in [errors] rather than thrown, so the
  /// UI can show them next to the model.
  Future<bool> download(String id) async {
    final model = findModel(id);
    if (model == null || isDownloading(id)) return false;
    final cancel = DownloadCancel();
    _cancels[id] = cancel;
    _progress[id] = 0;
    errors.remove(id);
    notifyListeners();
    try {
      await runtime.download(model, cancel: cancel, onProgress: (received) {
        _progress[id] = received;
        notifyListeners();
      });
      _installed.add(id);
      return true;
    } on DownloadCancelled {
      return false;
    } catch (e) {
      errors[id] = _describe(e);
      return false;
    } finally {
      _progress.remove(id);
      _cancels.remove(id);
      notifyListeners();
    }
  }

  void cancel(String id) => _cancels[id]?.cancelled = true;

  Future<void> delete(String id) async {
    final model = findModel(id);
    if (model == null) return;
    await runtime.delete(model);
    _installed.remove(id);
    notifyListeners();
  }

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup')) {
      return 'No internet connection. Connect once to download; after that it works offline.';
    }
    if (text.contains('No space left') || text.contains('errno = 28')) {
      return 'Not enough free storage on this phone.';
    }
    return text.replaceFirst('HttpException: ', '');
  }
}
