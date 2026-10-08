import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/learning_models.dart';
import 'speech_endpointer.dart';

/// What the microphone side of a voice conversation needs.
abstract interface class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();

  /// Loudness readings (dBFS) while a recording is running.
  Stream<double> levels();

  /// Stops and returns the clip, or null if nothing usable was captured.
  Future<AudioCapture?> stop();

  /// Stops and discards the clip.
  Future<void> cancel();
}

/// Where the tutor's voice comes out.
abstract interface class SpeechOutput {
  /// Plays [wav] and completes when it has finished (or been stopped).
  Future<void> play(List<int> wav);
  Future<void> stop();
}

/// The conversation: speech to text, the tutor's reply, text to speech.
abstract interface class VoiceBackend {
  Future<String> transcribe(AudioCapture audio);
  Future<TutorTurn> reply(String userText);
  Future<SpeechAudio> speak(String text);
}

/// The tutor's side of one exchange: [display] is everything to read, [speech]
/// is the part worth saying aloud.
class TutorTurn {
  const TutorTurn({required this.display, required this.speech});

  final String display;
  final String speech;
}

/// One exchange in the conversation.
class VoiceTurn {
  const VoiceTurn({required this.user, required this.tutor, this.speech = ''});

  final String user;
  final String tutor;
  final String speech;
}

enum VoicePhase {
  /// Not started, or ended.
  idle,

  /// Waiting for the learner to start talking.
  listening,

  /// The learner is talking.
  hearing,

  /// The recording is being turned into text.
  transcribing,

  /// The tutor is working out a reply.
  thinking,

  /// The tutor is talking.
  speaking,

  /// Hands-free listening is paused until the learner resumes.
  paused,
}

/// A hands-free German conversation: the tutor listens, notices when the
/// learner has finished, answers aloud, and listens again, without the learner
/// pressing anything between turns.
///
/// Half-duplex on purpose: the microphone is closed while the tutor speaks, so
/// it never "hears" itself, and the learner can tap to skip a long reply.
/// Everything platform-specific sits behind [VoiceRecorder], [SpeechOutput] and
/// [VoiceBackend], so the whole loop is tested without a microphone.
class VoiceSession extends ChangeNotifier {
  VoiceSession({
    required this.recorder,
    required this.output,
    required this.backend,
    Duration endSilence = const Duration(milliseconds: 1200),
    this.maxSilentTurns = 2,
    this.maxErrors = 3,
    Duration Function()? clock,
    Duration hardTurnLimit = const Duration(seconds: 60),
    this.startTimeout = const Duration(seconds: 6),
  })  : _endpointer = SpeechEndpointer(endSilence: endSilence),
        _clock = clock ?? _wallClock(),
        _hardTurnLimit = hardTurnLimit;

  final VoiceRecorder recorder;
  final SpeechOutput output;
  final VoiceBackend backend;

  /// How many waiting periods with no speech before listening pauses itself.
  final int maxSilentTurns;

  /// How many failures in a row before listening pauses itself.
  final int maxErrors;

  /// How long the microphone may take to open before it counts as failed.
  final Duration startTimeout;

  final SpeechEndpointer _endpointer;
  final Duration Function() _clock;
  final Duration _hardTurnLimit;

  static Duration Function() _wallClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  VoicePhase _phase = VoicePhase.idle;
  final List<VoiceTurn> _turns = [];
  String? _notice;
  String _heard = '';
  var _token = 0;
  var _running = false;
  var _silentTurns = 0;
  var _errors = 0;
  var _disposed = false;

  /// The turn currently being listened to, so stopping can end the wait.
  Completer<Endpoint>? _turnGate;

  /// Loudness of the learner's voice, 0 to 1, for the level meter.
  final ValueNotifier<double> level = ValueNotifier(0);

  VoicePhase get phase => _phase;
  List<VoiceTurn> get turns => List.unmodifiable(_turns);

  /// A short plain-language message about what just happened, if anything.
  String? get notice => _notice;

  /// The last thing the learner said, as understood.
  String get heard => _heard;

  bool get isActive => _running && _phase != VoicePhase.paused;

  /// Called after each completed exchange.
  void Function(VoiceTurn turn)? onTurn;

  // -------------------------------------------------------------------- control

  /// Starts (or restarts) the hands-free conversation. The conversation then
  /// runs by itself until [pause] or [stop]; this returns once it has begun.
  Future<void> start() async {
    if (_running || _disposed) return;
    _running = true;
    _silentTurns = 0;
    _errors = 0;
    _notice = null;
    final token = ++_token;

    bool allowed;
    try {
      allowed = await recorder.hasPermission();
    } catch (_) {
      allowed = false;
    }
    if (!_isCurrent(token)) return;
    if (!allowed) {
      _pause(
          'Microphone access is off. Turn it on for Sprichst in your device settings to talk with your tutor.');
      return;
    }
    unawaited(_loop(token));
  }

  /// Stops listening until [resume]. Whatever is in progress is dropped.
  Future<void> pause() async {
    if (!_running) return;
    _token++;
    await _quiesce();
    _pause(null);
  }

  Future<void> resume() async {
    if (_phase != VoicePhase.paused) return;
    _running = false;
    await start();
  }

  /// Ends the conversation.
  Future<void> stop() async {
    if (_phase == VoicePhase.idle && !_running) return; // already stopped
    _token++;
    _running = false;
    await _quiesce();
    _setPhase(VoicePhase.idle);
  }

  /// Cuts the tutor's reply short and goes back to listening.
  Future<void> skip() async {
    if (_phase == VoicePhase.speaking) await output.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    _running = false;
    unawaited(_quiesce());
    level.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------- loop

  bool _isCurrent(int token) => !_disposed && _running && token == _token;

  Future<void> _loop(int token) async {
    while (_isCurrent(token)) {
      await _turn(token);
    }
  }

  Future<void> _turn(int token) async {
    // 1. Listen.
    final heard = await _listen(token);
    if (!_isCurrent(token)) return;
    final audio = heard.audio;
    if (audio == null) {
      if (heard.silent && ++_silentTurns >= maxSilentTurns) {
        _pause(
            'I did not hear anything, so I paused. Tap the microphone when you are ready.');
      }
      return;
    }
    _silentTurns = 0;

    // 2. Understand.
    _setPhase(VoicePhase.transcribing);
    String text;
    try {
      text = (await backend.transcribe(audio)).trim();
    } catch (error) {
      if (!_isCurrent(token)) return;
      _failed(
          'I could not reach the AI server to understand you. Check Account → AI & voice → AI server.',
          error);
      return;
    }
    if (!_isCurrent(token)) return;
    if (text.isEmpty || looksLikeNoise(text)) {
      _setPhase(VoicePhase.listening);
      return;
    }
    _heard = text;
    _notice = null;

    // 3. Think.
    _setPhase(VoicePhase.thinking);
    TutorTurn reply;
    try {
      reply = await backend.reply(text);
    } catch (error) {
      if (!_isCurrent(token)) return;
      _failed(
          'The tutor could not answer. Check your connection and Account → AI & voice → AI server.',
          error);
      return;
    }
    if (!_isCurrent(token)) return;
    _errors = 0;
    final turn =
        VoiceTurn(user: text, tutor: reply.display, speech: reply.speech);
    _turns.add(turn);
    onTurn?.call(turn);
    notifyListeners();

    // 4. Speak. A voice problem must not end the conversation: the reply is
    // still on screen.
    if (reply.speech.trim().isEmpty) return;
    _setPhase(VoicePhase.speaking);
    try {
      final audio = await backend.speak(reply.speech);
      if (!_isCurrent(token)) return;
      await output.play(audio.bytes);
    } catch (error) {
      if (!_isCurrent(token)) return;
      _notice =
          'I could not play the voice this time. You can still read my answer.';
      debugPrint('Voice playback failed: $error');
    }
  }

  /// Opens the microphone and waits for one spoken turn. The result has the
  /// clip, or no clip and whether that was because nobody spoke (as opposed to
  /// something going wrong).
  Future<({AudioCapture? audio, bool silent})> _listen(int token) async {
    const nothing = (audio: null, silent: false);
    _endpointer.reset();
    level.value = 0;
    _setPhase(VoicePhase.listening);

    try {
      await recorder.start().timeout(startTimeout);
    } on TimeoutException catch (error) {
      unawaited(_safely(recorder.cancel()));
      if (_isCurrent(token)) {
        _failed(
            'The microphone did not start. Check that no other app is using it.',
            error);
      }
      return nothing;
    } catch (error) {
      if (_isCurrent(token)) {
        _failed('The microphone is not available right now.', error);
      }
      return nothing;
    }
    if (!_isCurrent(token)) {
      await recorder.cancel();
      return nothing;
    }

    final finished = Completer<Endpoint>();
    _turnGate = finished;
    final subscription = recorder.levels().listen(
      (db) {
        if (finished.isCompleted || !_isCurrent(token)) return;
        final event = _endpointer.feed(db, _clock());
        level.value = _endpointer.level;
        switch (event) {
          case Endpoint.speechStarted:
            _setPhase(VoicePhase.hearing);
          case Endpoint.speechEnded || Endpoint.noSpeech:
            finished.complete(event);
          case Endpoint.none:
            break;
        }
      },
      onError: (Object error) {
        if (!finished.isCompleted) finished.complete(Endpoint.noSpeech);
      },
    );
    // If readings stop arriving the turn must still end.
    final watchdog = Timer(_hardTurnLimit, () {
      if (!finished.isCompleted) finished.complete(Endpoint.noSpeech);
    });

    final outcome = await finished.future;
    if (identical(_turnGate, finished)) _turnGate = null;
    watchdog.cancel();
    await subscription.cancel();
    level.value = 0;

    if (!_isCurrent(token)) {
      await recorder.cancel();
      return nothing;
    }
    if (outcome == Endpoint.speechEnded) {
      try {
        final clip = await recorder.stop();
        if (clip == null) return (audio: null, silent: true);
        return (audio: clip, silent: false);
      } catch (error) {
        _failed('The recording could not be saved.', error);
        return nothing;
      }
    }
    await recorder.cancel();
    return (audio: null, silent: true);
  }

  // -------------------------------------------------------------------- helpers

  void _failed(String message, Object error) {
    debugPrint('Voice turn failed: $error');
    _errors++;
    _notice = message;
    if (_errors >= maxErrors) {
      _pause('$message I paused listening.');
    } else {
      _setPhase(VoicePhase.listening);
    }
  }

  void _pause(String? message) {
    _running = false;
    _token++;
    _notice = message;
    level.value = 0;
    _setPhase(VoicePhase.paused);
  }

  Future<void> _quiesce() async {
    // Wake a turn that is still waiting for speech so it can wind down.
    final gate = _turnGate;
    if (gate != null && !gate.isCompleted) gate.complete(Endpoint.noSpeech);
    // Closing must never hang the screen, even if a device driver does.
    await _safely(output.stop());
    await _safely(recorder.cancel());
    if (!_disposed) level.value = 0;
  }

  Future<void> _safely(Future<void> work) async {
    try {
      await work.timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _setPhase(VoicePhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  /// Whisper tends to invent captions out of silence or background noise.
  /// These are the usual ones; a real learner turn never looks like this.
  @visibleForTesting
  static bool looksLikeNoise(String text) {
    final lower = text.toLowerCase();
    if (lower.replaceAll(RegExp(r'[^a-zäöüß]'), '').length < 2) return true;
    return const [
      'untertitel',
      'amara.org',
      'vielen dank fürs zuschauen',
      'thanks for watching',
      '[musik]',
      '(musik)',
      '[applaus]',
      'copyright',
    ].any(lower.contains);
  }
}
