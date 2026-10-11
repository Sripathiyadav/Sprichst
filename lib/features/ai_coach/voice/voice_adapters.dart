import '../../../app/app_controller.dart';
import '../../../domain/models/learning_models.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import 'voice_session.dart';

/// Connects the real microphone to [VoiceSession].
class MicrophoneRecorder implements VoiceRecorder {
  MicrophoneRecorder([AudioRecorderService? service])
      : _service = service ?? AudioRecorderService();

  final AudioRecorderService _service;

  @override
  Future<bool> hasPermission() => _service.hasPermission();

  @override
  Future<void> start() => _service.start();

  @override
  Stream<double> levels() => _service.levels();

  @override
  Future<AudioCapture?> stop() async {
    final audio = await _service.stop();
    return audio == null
        ? null
        : AudioCapture(
            bytes: audio.bytes,
            filename: audio.filename,
            mimeType: audio.mimeType,
          );
  }

  @override
  Future<void> cancel() => _service.cancel();

  Future<void> dispose() => _service.dispose();
}

/// Connects the real speaker to [VoiceSession].
class SpeakerOutput implements SpeechOutput {
  SpeakerOutput([AudioPlayerService? service])
      : _service = service ?? AudioPlayerService();

  final AudioPlayerService _service;

  @override
  Future<void> play(List<int> wav) => _service.playBytes(wav);

  @override
  Future<void> stop() => _service.stop();

  Future<void> dispose() => _service.dispose();
}

/// Connects the app's tutor (transcription, chat, speech) to [VoiceSession].
class AppVoiceBackend implements VoiceBackend {
  AppVoiceBackend(this._app);

  final AppController _app;

  @override
  Future<String> transcribe(AudioCapture audio) => _app.transcribe(audio);

  @override
  Future<TutorTurn> reply(String userText) async =>
      tutorTurnFrom(await _app.chat(userText));

  @override
  Future<SpeechAudio> speak(String text) => _app.speak(text);
}

/// Splits a tutor reply into what to show and what to say aloud: the spoken
/// version skips the written explanation, which is meant to be read.
TutorTurn tutorTurnFrom(TutorReply reply) {
  String? clean(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final correction = clean(reply.correction);
  final explanation = clean(reply.explanation);
  final followUp = clean(reply.followUp);

  return TutorTurn(
    display: [
      if (clean(reply.reply) != null) reply.reply,
      if (correction != null) 'Correction: $correction',
      if (explanation != null) explanation,
      if (followUp != null) followUp,
    ].join('\n\n'),
    speech: [
      if (clean(reply.reply) != null) reply.reply,
      if (correction != null) correction,
      if (followUp != null) followUp,
    ].join(' ').trim(),
  );
}
