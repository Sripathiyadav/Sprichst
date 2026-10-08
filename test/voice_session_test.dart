import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/features/ai_coach/voice/voice_session.dart';

import 'support/voice_fakes.dart';

void main() {
  test('one full hands-free exchange, then it listens again by itself',
      () async {
    final h = Harness();
    final turns = <VoiceTurn>[];
    h.session.onTurn = turns.add;
    await h.begin();
    expect(h.session.phase, VoicePhase.listening);

    await h.sound(quietDb, 500);
    await h.sound(speechDb, 600);
    expect(h.session.phase, VoicePhase.hearing);

    await h.sound(speechDb, 400);
    await h.sound(quietDb, 1500);
    await pumpEventQueue();

    // The tutor is now speaking its reply.
    expect(h.session.phase, VoicePhase.speaking);
    expect(h.backend.replies, ['Hallo, wie geht es dir?']);
    expect(h.backend.spoken, ['Mir geht es gut!']);
    expect(h.output.played, hasLength(1));
    expect(turns.single.user, 'Hallo, wie geht es dir?');

    // The reply finishes: the microphone opens again without any tap.
    h.output.playing!.complete();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.listening);
    expect(h.recorder.starts, 2);

    await h.session.stop();
    expect(h.session.phase, VoicePhase.idle);
  });

  test('the microphone is closed while the tutor speaks', () async {
    final h = Harness();
    await h.begin();
    await h.saySomething();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.speaking);
    expect(h.recorder.starts, 1); // not recording during playback
    await h.session.stop();
  });

  test('pauses itself after two silent waits, with a plain message', () async {
    final h = Harness();
    await h.begin();
    // Twelve seconds of quiet, twice.
    await h.sound(quietDb, 12500);
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.listening);
    expect(h.recorder.starts, 2);
    await h.sound(quietDb, 12500);
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.paused);
    expect(h.session.notice, contains('did not hear anything'));
    expect(h.backend.replies, isEmpty);
  });

  test('made-up captions from background noise are ignored', () async {
    final h = Harness();
    h.backend.transcripts
        .addAll(['Untertitel der Amara.org-Community', 'Guten Tag!']);
    await h.begin();
    await h.saySomething();
    await pumpEventQueue();
    expect(h.backend.replies, isEmpty);
    expect(h.session.phase, VoicePhase.listening);

    await h.saySomething();
    await pumpEventQueue();
    expect(h.backend.replies, ['Guten Tag!']);
    await h.session.stop();
  });

  test('a failed transcription keeps going; three in a row pause', () async {
    final h = Harness();
    h.backend.transcribeError = Exception('gateway down');
    await h.begin();
    for (var i = 0; i < 2; i++) {
      await h.saySomething();
      await pumpEventQueue();
      expect(h.session.phase, VoicePhase.listening, reason: 'attempt $i');
      expect(h.session.notice, isNotNull);
    }
    await h.saySomething();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.paused);
    expect(h.session.notice, contains('paused'));
  });

  test('a voice failure keeps the reply and keeps listening', () async {
    final h = Harness();
    h.backend.speakError = Exception('tts down');
    await h.begin();
    await h.saySomething();
    await pumpEventQueue();
    expect(h.session.turns, hasLength(1));
    expect(h.session.phase, VoicePhase.listening);
    expect(h.session.notice, contains('read my answer'));
    await h.session.stop();
  });

  test('skip cuts the reply short and listens again', () async {
    final h = Harness();
    await h.begin();
    await h.saySomething();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.speaking);
    await h.session.skip();
    await pumpEventQueue();
    expect(h.output.stops, greaterThanOrEqualTo(1));
    expect(h.session.phase, VoicePhase.listening);
    await h.session.stop();
  });

  test('pause drops the turn in progress and resume starts a fresh one',
      () async {
    final h = Harness();
    await h.begin();
    await h.sound(quietDb, 500);
    await h.sound(speechDb, 600);
    await h.session.pause();
    expect(h.session.phase, VoicePhase.paused);
    expect(h.recorder.cancels, greaterThanOrEqualTo(1));
    expect(h.backend.replies, isEmpty);

    await h.session.resume();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.listening);
    expect(h.recorder.starts, 2);
    await h.session.stop();
  });

  test('a result that arrives after pausing is thrown away', () async {
    final h = Harness();
    h.backend.transcribeGate = Completer<String>();
    await h.begin();
    await h.saySomething();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.transcribing);

    await h.session.pause();
    h.backend.transcribeGate!.complete('Zu spät');
    await pumpEventQueue();
    expect(h.session.turns, isEmpty);
    expect(h.backend.replies, isEmpty);
    expect(h.session.phase, VoicePhase.paused);
  });

  test('no microphone permission pauses with an explanation', () async {
    final h = Harness();
    h.recorder.allowed = false;
    await h.begin();
    expect(h.session.phase, VoicePhase.paused);
    expect(h.session.notice, contains('Microphone access is off'));
    expect(h.recorder.starts, 0);
  });

  test('a microphone that cannot start does not spin forever', () async {
    final h = Harness();
    h.recorder.failStart = true;
    await h.begin();
    await pumpEventQueue();
    expect(h.session.phase, VoicePhase.paused);
    expect(h.session.notice, contains('microphone'));
  });

  test('a microphone that never opens fails cleanly instead of hanging',
      () async {
    final h = Harness(startTimeout: const Duration(milliseconds: 50));
    h.recorder.hangStart = true;
    await h.begin();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(h.session.phase, VoicePhase.paused);
    expect(h.session.notice, contains('did not start'));
  });

  test('ending returns promptly even if the recorder is stuck', () async {
    final h = Harness();
    await h.begin();
    h.recorder.hangCancel = true;
    final watch = Stopwatch()..start();
    await h.session.stop();
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    expect(h.session.phase, VoicePhase.idle);
  });

  test('noise filter catches captions but not real German', () {
    expect(
        VoiceSession.looksLikeNoise('Untertitel im Auftrag des ZDF'), isTrue);
    expect(VoiceSession.looksLikeNoise('...'), isTrue);
    expect(VoiceSession.looksLikeNoise('Ich möchte einen Kaffee.'), isFalse);
    expect(VoiceSession.looksLikeNoise('Ja'), isFalse);
  });
}
