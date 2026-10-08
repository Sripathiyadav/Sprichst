import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_catalogue.dart';
import 'on_device_runtime.dart';
import 'wav.dart';

OnDeviceRuntime createOnDeviceRuntime() => IoOnDeviceRuntime();

/// Runs the models with llama.cpp (tutor) and sherpa-onnx (Whisper, Piper).
///
/// Models live in Application Support/models/<id>/; a `.complete` marker is
/// written only after every file has arrived and been unpacked, so a download
/// interrupted at any point is never mistaken for an installed model. On iOS
/// the AppDelegate keeps the models folder out of iCloud backups.
class IoOnDeviceRuntime implements OnDeviceRuntime {
  IoOnDeviceRuntime({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _deviceInfo = DeviceInfoPlugin();
  Directory? _root;

  LlamaEngine? _engine;
  String? _engineModelId;
  Future<void>? _loading;

  @override
  bool get isSupported => true;

  @override
  Future<int?> deviceRamMb() async {
    try {
      if (Platform.isIOS) return (await _deviceInfo.iosInfo).physicalRamSize;
      if (Platform.isAndroid) {
        return (await _deviceInfo.androidInfo).physicalRamSize;
      }
      if (Platform.isMacOS) {
        return (await _deviceInfo.macOsInfo).memorySize ~/ (1024 * 1024);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> isSimulator() async {
    try {
      if (Platform.isIOS) return !(await _deviceInfo.iosInfo).isPhysicalDevice;
      if (Platform.isAndroid) {
        return !(await _deviceInfo.androidInfo).isPhysicalDevice;
      }
    } catch (_) {}
    return false;
  }

  Future<Directory> _dirFor(OnDeviceModel model) async {
    _root ??=
        Directory('${(await getApplicationSupportDirectory()).path}/models');
    return Directory('${_root!.path}/${model.id}');
  }

  /// espeak-ng's phoneme data, shared by every Piper voice. It lives near the
  /// top of the app's storage because espeak ignores a data path of 256
  /// characters or more, and a nested path inside a voice folder can exceed
  /// that (it did on the iOS simulator).
  Future<String> _espeakDir() async =>
      '${(await getApplicationSupportDirectory()).path}/models/espeak-ng-data';

  @override
  Future<bool> isInstalled(OnDeviceModel model) async =>
      File('${(await _dirFor(model)).path}/.complete').exists();

  @override
  Future<void> download(
    OnDeviceModel model, {
    required void Function(int received) onProgress,
    DownloadCancel? cancel,
  }) async {
    final dir = await _dirFor(model);
    await dir.create(recursive: true);
    var done = 0;
    for (final file in model.files) {
      final target = File('${dir.path}/${file.name}');
      if (!file.archive &&
          await target.exists() &&
          await target.length() == file.bytes) {
        done += file.bytes;
        onProgress(done);
        continue;
      }
      final before = done;
      await _fetch(file, File('${target.path}.part'),
          onProgress: (n) => onProgress(before + n), cancel: cancel);
      await File('${target.path}.part').rename(target.path);
      done += file.bytes;
      if (file.archive) {
        await _unpack(target.path, dir.path);
        await target.delete();
        await _flattenVoice(dir);
      }
    }
    await File('${dir.path}/.complete').writeAsString(model.id);
  }

  /// Moves an unpacked voice's files up out of its `vits-piper-*` folder and
  /// its espeak data to the shared [_espeakDir], keeping paths short.
  Future<void> _flattenVoice(Directory dir) async {
    final nested = [
      await for (final e in dir.list())
        if (e is Directory && e.path.split('/').last.startsWith('vits-piper-'))
          e,
    ];
    for (final folder in nested) {
      await for (final entity in folder.list()) {
        final name = entity.path.split('/').last;
        if (name == 'espeak-ng-data') {
          final shared = Directory(await _espeakDir());
          if (await shared.exists()) {
            await entity.delete(recursive: true);
          } else {
            await entity.rename(shared.path);
          }
        } else {
          await entity.rename('${dir.path}/$name');
        }
      }
      await folder.delete(recursive: true);
    }
  }

  /// Streams [file] into [part], resuming from what is already there.
  Future<void> _fetch(
    ModelFile file,
    File part, {
    required void Function(int received) onProgress,
    DownloadCancel? cancel,
  }) async {
    var have = await part.exists() ? await part.length() : 0;
    if (have > file.bytes) {
      await part.delete();
      have = 0;
    }
    if (have == file.bytes) return;

    final request = http.Request('GET', Uri.parse(file.url));
    if (have > 0) request.headers['Range'] = 'bytes=$have-';
    final response = await _client.send(request);
    if (response.statusCode == 200) {
      have = 0; // the server ignored the range: start over
    } else if (response.statusCode != 206) {
      throw HttpException(
          'Download failed (${response.statusCode}) for ${file.url}');
    }

    final sink =
        part.openWrite(mode: have == 0 ? FileMode.write : FileMode.append);
    var received = have;
    var reported = 0;
    try {
      await for (final chunk in response.stream) {
        if (cancel?.cancelled ?? false) throw DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (received - reported > 512 * 1024) {
          reported = received;
          onProgress(received);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (received != file.bytes) {
      throw HttpException(
          'Download incomplete: got $received of ${file.bytes} bytes. Try again to resume.');
    }
    onProgress(received);
  }

  @override
  Future<void> delete(OnDeviceModel model) async {
    if (_engineModelId == model.id) await unloadTutor();
    final dir = await _dirFor(model);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // --- Tutor -----------------------------------------------------------------

  Future<LlamaEngine> _tutor(OnDeviceModel model) async {
    while (_loading != null) {
      await _loading;
    }
    if (_engine != null && _engineModelId == model.id) return _engine!;
    final load = _load(model);
    _loading = load;
    try {
      await load;
    } finally {
      _loading = null;
    }
    return _engine!;
  }

  Future<void> _load(OnDeviceModel model) async {
    await unloadTutor();
    final engine = LlamaEngine(LlamaBackend());
    final simulator = await isSimulator();
    await engine.loadModel(
      '${(await _dirFor(model)).path}/model.gguf',
      modelParams: ModelParams(
        contextSize: 2048,
        // Simulators have no usable GPU; real phones use Metal or the CPU.
        preferredBackend: simulator ? GpuBackend.cpu : GpuBackend.auto,
        gpuLayers: simulator ? 0 : ModelParams.maxGpuLayers,
      ),
    );
    _engine = engine;
    _engineModelId = model.id;
  }

  @override
  Future<String> generateJson(
    OnDeviceModel model,
    List<TutorMessage> messages, {
    required Map<String, dynamic> jsonSchema,
    int maxTokens = 320,
  }) async {
    final engine = await _tutor(model);
    final out = StringBuffer();
    await for (final chunk in engine.create(
      [
        for (final m in messages)
          LlamaChatMessage.fromText(
            role:
                m.role == 'system' ? LlamaChatRole.system : LlamaChatRole.user,
            text: m.text,
          ),
      ],
      params: GenerationParams(maxTokens: maxTokens, temp: 0.2),
      enableThinking: false,
      responseFormat: {
        'type': 'json_schema',
        'json_schema': {'schema': jsonSchema},
      },
    )) {
      final text = chunk.choices.first.delta.content;
      if (text != null) out.write(text);
    }
    return out.toString();
  }

  @override
  Future<void> unloadTutor() async {
    final engine = _engine;
    _engine = null;
    _engineModelId = null;
    await engine?.dispose();
  }

  // --- Speech ----------------------------------------------------------------

  @override
  Future<String> transcribe(OnDeviceModel model, List<int> wavBytes) async {
    final dir = (await _dirFor(model)).path;
    for (final name in ['encoder.onnx', 'decoder.onnx', 'tokens.txt']) {
      if (!await File('$dir/$name').exists()) {
        throw StateError(
            'Speech recognition is not installed correctly. Delete and download it again.');
      }
    }
    return _runTranscribe(dir, Uint8List.fromList(wavBytes));
  }

  @override
  Future<List<int>> synthesize(
    OnDeviceModel voice,
    String text, {
    double lengthScale = 1.0,
  }) async {
    final dir = await _dirFor(voice);
    final files = await _voiceFiles(dir, voice.id);
    final speaker = await _speakerId(files.model, voiceSpeakers[voice.id]);
    return _runSynthesize(files, text, lengthScale, speaker);
  }

  Future<_VoiceFiles> _voiceFiles(Directory dir, String id) async {
    final files = _VoiceFiles(
        '${dir.path}/$id.onnx', '${dir.path}/tokens.txt', await _espeakDir());
    // sherpa-onnx ends the whole app (exit()) on a bad config, so anything
    // it would reject is caught here as an ordinary error instead.
    if (!await File(files.model).exists() ||
        !await File(files.tokens).exists() ||
        !await File('${files.dataDir}/phontab').exists()) {
      throw StateError(
          'The voice $id is not installed correctly. Delete and download it again.');
    }
    if (files.dataDir.length >= 250) {
      throw StateError('The voice data path is too long for espeak-ng.');
    }
    return files;
  }

  Future<int> _speakerId(String modelPath, String? speaker) async {
    if (speaker == null) return 0;
    try {
      final config = jsonDecode(await File('$modelPath.json').readAsString())
          as Map<String, dynamic>;
      final map = config['speaker_id_map'] as Map<String, dynamic>? ?? const {};
      return map[speaker] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

class _VoiceFiles {
  const _VoiceFiles(this.model, this.tokens, this.dataDir);
  final String model;
  final String tokens;
  final String dataDir;
}

// These run in a background isolate: sherpa-onnx calls are synchronous and
// unpacking is slow. They are top-level so each closure captures only its
// arguments (an instance method's closure would try to send `this`).

Future<void> _unpack(String archive, String into) =>
    Isolate.run(() => extractFileToDisk(archive, into));

Future<String> _runTranscribe(String dir, Uint8List wav) =>
    Isolate.run(() => _transcribe(dir, wav));

Future<Uint8List> _runSynthesize(
        _VoiceFiles files, String text, double lengthScale, int speaker) =>
    Isolate.run(() => _synthesize(files, text, lengthScale, speaker));

String _transcribe(String dir, Uint8List wavBytes) {
  sherpa.initBindings();
  final wav = decodeWav(wavBytes);
  final recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(
      whisper: sherpa.OfflineWhisperModelConfig(
        encoder: '$dir/encoder.onnx',
        decoder: '$dir/decoder.onnx',
        language: 'de',
        task: 'transcribe',
      ),
      tokens: '$dir/tokens.txt',
      numThreads: 2,
      debug: false,
    ),
  ));
  final stream = recognizer.createStream();
  try {
    stream.acceptWaveform(samples: wav.samples, sampleRate: wav.sampleRate);
    recognizer.decode(stream);
    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
    recognizer.free();
  }
}

Uint8List _synthesize(
    _VoiceFiles files, String text, double lengthScale, int speaker) {
  sherpa.initBindings();
  final tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
    model: sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(
        model: files.model,
        tokens: files.tokens,
        dataDir: files.dataDir,
      ),
      numThreads: 2,
      debug: false,
    ),
  ));
  try {
    final audio =
        tts.generate(text: text, sid: speaker, speed: 1 / lengthScale);
    return encodeWav(audio.samples, audio.sampleRate);
  } finally {
    tts.free();
  }
}
