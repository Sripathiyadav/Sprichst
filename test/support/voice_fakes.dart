import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/domain/models/learning_models.dart';
import 'package:sprichst/features/ai_coach/voice/voice_session.dart';

const quietDb = -62.0;
const speechDb = -22.0;

class FakeRecorder implements VoiceRecorder {
  bool allowed = true;
  bool failStart = false;
  bool hangStart = false;
  bool hangCancel = false;
  var starts = 0;
  var cancels = 0;
  var stops = 0;
  StreamController<double>? _levels;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start() async {
    if (failStart) throw StateError('no mic');
    if (hangStart) return Completer<void>().future;
    starts++;
    _levels = StreamController<double>.broadcast();
  }

  @override
  Stream<double> levels() => _levels!.stream;

  @override
  Future<AudioCapture?> stop() async {
    stops++;
    await _levels?.close();
    return const AudioCapture(
        bytes: [1, 2, 3], filename: 'clip.wav', mimeType: 'audio/wav');
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (hangCancel) return Completer<void>().future;
    await _levels?.close();
  }

  void emit(double db) {
    final controller = _levels;
    if (controller != null && !controller.isClosed) controller.add(db);
  }
}

class FakeOutput implements SpeechOutput {
  final played = <List<int>>[];
  Completer<void>? playing;
  var stops = 0;

  @override
  Future<void> play(List<int> wav) {
    played.add(wav);
    playing = Completer<void>();
    return playing!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (playing != null && !playing!.isCompleted) playing!.complete();
  }
}

class FakeBackend implements VoiceBackend {
  final transcripts = <String>[];
  Object? transcribeError;
  Object? speakError;
  Completer<String>? transcribeGate;
  var spoken = <String>[];
  final replies = <String>[];

  @override
  Future<String> transcribe(AudioCapture audio) async {
    if (transcribeError != null) throw transcribeError!;
    if (transcribeGate != null) return transcribeGate!.future;
    return transcripts.isEmpty
        ? 'Hallo, wie geht es dir?'
        : transcripts.removeAt(0);
  }

  @override
  Future<TutorTurn> reply(String userText) async {
    replies.add(userText);
    return TutorTurn(
        display: 'Mir geht es gut! ($userText)', speech: 'Mir geht es gut!');
  }

  @override
  Future<SpeechAudio> speak(String text) async {
    if (speakError != null) throw speakError!;
    spoken.add(text);
    return const SpeechAudio([9, 9]);
  }
}

class Harness {
  Harness({Duration startTimeout = const Duration(seconds: 6)}) {
    session = VoiceSession(
      startTimeout: startTimeout,
      recorder: recorder,
      output: output,
      backend: backend,
      clock: () => Duration(milliseconds: ms),
      hardTurnLimit: const Duration(minutes: 5),
    );
  }

  final recorder = FakeRecorder();
  final output = FakeOutput();
  final backend = FakeBackend();
  late final VoiceSession session;
  var ms = 0;

  /// Plays [db] into the microphone for [duration], 100 ms at a time.
  Future<void> sound(double db, int duration) async {
    for (var t = 0; t < duration; t += 100) {
      ms += 100;
      recorder.emit(db);
      await pumpEventQueue();
    }
  }

  /// A whole spoken turn: a moment of room noise, speech, then the pause.
  Future<void> saySomething() async {
    await sound(quietDb, 500);
    await sound(speechDb, 1000);
    await sound(quietDb, 1500);
  }

  Future<void> begin() async {
    await session.start();
    await pumpEventQueue();
  }
}
