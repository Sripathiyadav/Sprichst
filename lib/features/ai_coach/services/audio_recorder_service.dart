import 'dart:async';

import 'package:record/record.dart';

import 'audio_bytes_reader.dart';
import 'recording_files.dart';

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

/// Records short spoken clips as 16 kHz mono WAV, the format the speech gateway
/// expects.
class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
  );

  /// Whether recording is allowed. The first call shows the system permission
  /// prompt; later calls report the saved choice.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    await _recorder.start(_config, path: await newRecordingPath());
  }

  /// Stops recording and returns the clip, or null if nothing usable was
  /// captured. The temporary file is always removed.
  Future<RecordedAudio?> stop() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;

    try {
      final bytes = await readAudioBytes(path);
      if (bytes.isEmpty) return null;

      return RecordedAudio(
        bytes: bytes,
        filename: 'sprichst_recording.wav',
        mimeType: 'audio/wav',
      );
    } finally {
      await deleteRecording(path);
    }
  }

  /// Loudness readings (dBFS) while recording, about every [interval]. Hands-free
  /// voice mode uses them to notice when the learner starts and stops talking.
  ///
  /// This polls the recorder itself instead of using `onAmplitudeChanged`: that
  /// stream stops delivering after the first recording ends, which would leave
  /// every turn after the first deaf.
  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    late final StreamController<double> controller;
    Timer? timer;
    var polling = false;
    controller = StreamController<double>(
      onListen: () {
        timer = Timer.periodic(interval, (_) async {
          if (polling || controller.isClosed) return;
          polling = true;
          try {
            final amplitude = await _recorder.getAmplitude();
            if (!controller.isClosed) controller.add(amplitude.current);
          } catch (_) {
            // A missed reading is harmless; the next one will arrive.
          } finally {
            polling = false;
          }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  /// Stops and throws the clip away.
  Future<void> cancel() async {
    await stop();
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<void> dispose() => _recorder.dispose();
}
