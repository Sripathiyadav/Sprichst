import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/features/ai_coach/voice/speech_endpointer.dart';

const _tick = Duration(milliseconds: 100);

/// Feeds [db] readings every 100 ms from [start]; returns the first event that
/// is not [Endpoint.none] with the time it happened.
(Endpoint, Duration)? _feed(
  SpeechEndpointer e,
  double db,
  Duration start,
  Duration length,
) {
  for (var t = start; t < start + length; t += _tick) {
    final event = e.feed(db, t);
    if (event != Endpoint.none) return (event, t);
  }
  return null;
}

/// Feeds every reading, ignoring events (for setting up a situation).
void _pump(SpeechEndpointer e, double db, Duration start, Duration length) {
  for (var t = start; t < start + length; t += _tick) {
    e.feed(db, t);
  }
}

void main() {
  const quiet = -62.0;
  const speech = -22.0;

  test('quiet room that stays quiet times out with no speech', () {
    final e = SpeechEndpointer(noSpeechTimeout: const Duration(seconds: 5));
    final result = _feed(e, quiet, Duration.zero, const Duration(seconds: 8));
    expect(result?.$1, Endpoint.noSpeech);
    expect(result!.$2, const Duration(seconds: 5));
  });

  test('detects speech, then ends the turn after the pause', () {
    final e = SpeechEndpointer(endSilence: const Duration(milliseconds: 1000));
    expect(_feed(e, quiet, Duration.zero, const Duration(seconds: 1)), isNull);

    final started = _feed(
        e, speech, const Duration(seconds: 1), const Duration(seconds: 1));
    expect(started?.$1, Endpoint.speechStarted);
    expect(e.isSpeaking, isTrue);

    // Keep talking for two seconds: nothing happens.
    expect(
        _feed(
            e, speech, const Duration(seconds: 2), const Duration(seconds: 2)),
        isNull);

    final ended =
        _feed(e, quiet, const Duration(seconds: 4), const Duration(seconds: 3));
    expect(ended?.$1, Endpoint.speechEnded);
    // The last loud reading was at 3.9 s; one second of quiet ends the turn.
    expect(ended!.$2, const Duration(milliseconds: 4900));
    expect(e.isDone, isTrue);
  });

  test('a short pause inside a sentence does not end the turn', () {
    final e = SpeechEndpointer(endSilence: const Duration(milliseconds: 1200));
    _pump(e, quiet, Duration.zero, const Duration(milliseconds: 600));
    _pump(e, speech, const Duration(milliseconds: 600),
        const Duration(seconds: 1));
    final pause = _feed(e, quiet, const Duration(milliseconds: 1600),
        const Duration(milliseconds: 800));
    expect(pause, isNull);
    final more = _feed(e, speech, const Duration(milliseconds: 2400),
        const Duration(seconds: 1));
    expect(more, isNull);
    expect(e.isSpeaking, isTrue);
  });

  test('a brief noise is not speech', () {
    final e = SpeechEndpointer(minSpeech: const Duration(milliseconds: 300));
    _feed(e, quiet, Duration.zero, const Duration(milliseconds: 600));
    // A 100 ms click.
    expect(e.feed(-10, const Duration(milliseconds: 600)), Endpoint.none);
    expect(e.feed(quiet, const Duration(milliseconds: 700)), Endpoint.none);
    expect(e.isSpeaking, isFalse);
  });

  test('a long monologue is cut at the maximum length', () {
    final e = SpeechEndpointer(maxUtterance: const Duration(seconds: 5));
    _feed(e, quiet, Duration.zero, const Duration(milliseconds: 600));
    final result = _feed(e, speech, const Duration(milliseconds: 600),
        const Duration(seconds: 10));
    expect(result?.$1, Endpoint.speechStarted);
    final end = _feed(e, speech, const Duration(milliseconds: 1500),
        const Duration(seconds: 10));
    expect(end?.$1, Endpoint.speechEnded);
  });

  test('adapts to a noisy room: steady noise is not speech', () {
    final e = SpeechEndpointer(noSpeechTimeout: const Duration(seconds: 3));
    const noisy = -42.0; // a fan, louder than a quiet room
    final result = _feed(e, noisy, Duration.zero, const Duration(seconds: 5));
    expect(result?.$1, Endpoint.noSpeech);
  });

  test('the threshold stays between its limits', () {
    final loud = SpeechEndpointer()..feed(-5, Duration.zero);
    for (var t = 100; t < 600; t += 100) {
      loud.feed(-5, Duration(milliseconds: t));
    }
    expect(
        loud.thresholdDb, lessThanOrEqualTo(SpeechEndpointer.maxThresholdDb));
    final silent = SpeechEndpointer();
    for (var t = 0; t < 600; t += 100) {
      silent.feed(-160, Duration(milliseconds: t));
    }
    expect(silent.thresholdDb,
        greaterThanOrEqualTo(SpeechEndpointer.minThresholdDb));
  });

  test('level is 0 to 1 and reset starts afresh', () {
    final e = SpeechEndpointer();
    for (var t = 0; t < 500; t += 100) {
      e.feed(quiet, Duration(milliseconds: t));
    }
    expect(e.level, closeTo(0, .1));
    e.feed(-15, const Duration(milliseconds: 500));
    expect(e.level, greaterThan(.8));
    e.reset();
    expect(e.isDone, isFalse);
    expect(e.isSpeaking, isFalse);
  });

  test('after the end, further readings are ignored until reset', () {
    final e = SpeechEndpointer(noSpeechTimeout: const Duration(seconds: 1));
    expect(_feed(e, quiet, Duration.zero, const Duration(seconds: 2))?.$1,
        Endpoint.noSpeech);
    expect(e.feed(speech, const Duration(seconds: 3)), Endpoint.none);
  });
}
