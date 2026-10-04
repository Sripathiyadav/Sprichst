import 'package:record/record.dart';

import 'audio_bytes_reader.dart';

class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    final config = const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
    );

    await _recorder.start(
      config,
      path: '',
    );
  }

  Future<RecordedAudio?> stop() async {
    final path = await _recorder.stop();

    if (path == null || path.isEmpty) {
      return null;
    }

    final bytes = await readAudioBytes(path);

    if (bytes.isEmpty) {
      return null;
    }

    return RecordedAudio(
      bytes: bytes,
      filename: 'sprichst_recording.wav',
      mimeType: 'audio/wav',
    );
  }

  Future<bool> isRecording() {
    return _recorder.isRecording();
  }

  Future<void> dispose() {
    return _recorder.dispose();
  }
}
