import 'dart:math' as math;

import '../models/curriculum.dart';
import '../models/learning_models.dart';

/// A German sentence to type, with its English meaning.
class TypingSentence {
  const TypingSentence(this.german, this.english);

  final String german;
  final String english;

  /// How many of the letters are ä ö ü ß (or capitals): the keys a learner
  /// without a German keyboard has to hunt for.
  int get specialLetters => TypingPractice.special.allMatches(german).length;
}

/// Typing practice for German: sentences from the learner's own lessons, the
/// keys that English keyboards lack, and honest speed and accuracy.
class TypingPractice {
  const TypingPractice._();

  /// ä ö ü ß and the capitals, as the practice screen's keys.
  static const keys = ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü'];
  static final special = RegExp('[äöüßÄÖÜ]');

  /// "Ich habe Hunger. — I am hungry (literally: …)." becomes the German and
  /// the English; null when [example] is not in that shape.
  static TypingSentence? parse(String example) {
    final parts = example.split(' — ');
    if (parts.length < 2) return null;
    final german = parts.first.trim();
    var english = parts.sublist(1).join(' — ').trim();
    english = english.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    if (german.isEmpty || english.isEmpty) return null;
    return TypingSentence(german, english);
  }

  /// Up to [count] sentences from lessons at or below [level], a different set
  /// for each [seed]. With [lettersFirst], sentences that need ä ö ü ß come
  /// first, so the keys get practice.
  static List<TypingSentence> pick(
    Curriculum curriculum,
    CefrLevel level, {
    int count = 5,
    int seed = 0,
    bool lettersFirst = true,
  }) {
    final all = <TypingSentence>{};
    for (final lesson in curriculum.lessons) {
      if (lesson.level.index > level.index) continue;
      for (final example in lesson.examples) {
        final sentence = parse(example);
        // Short enough to type in one go, long enough to be a sentence.
        if (sentence != null &&
            sentence.german.length >= 8 &&
            sentence.german.length <= 70) {
          all.add(sentence);
        }
      }
    }
    final list = all.toList()..shuffle(math.Random(seed));
    if (lettersFirst) {
      final withLetters = list.where((s) => s.specialLetters > 0).toList();
      final rest = list.where((s) => s.specialLetters == 0).toList();
      final mixed = [
        ...withLetters.take((count / 2).ceil()),
        ...rest,
        ...withLetters.skip((count / 2).ceil()),
      ];
      return mixed.take(count).toList();
    }
    return list.take(count).toList();
  }
}

/// One sentence being typed: what is typed so far, the mistakes made on the way
/// and how long it took. Pure, so it is easy to test.
class TypingRun {
  TypingRun(this.target);

  final String target;
  String typed = '';
  int mistakes = 0;
  int keystrokes = 0;
  DateTime? _started;
  DateTime? _finished;

  bool get started => _started != null;
  bool get finished => _finished != null;

  /// The learner changed the text to [next] at [now]. A new letter that is not
  /// the one expected counts as a mistake; deleting never does, so fixing a
  /// slip is free of a second penalty.
  void update(String next, DateTime now) {
    if (finished) return;
    if (next.isNotEmpty) _started ??= now;
    if (next.length > typed.length && next.startsWith(typed)) {
      for (var i = typed.length; i < next.length; i++) {
        keystrokes++;
        if (i >= target.length || next[i] != target[i]) mistakes++;
      }
    } else if (next.length > typed.length) {
      // Pasted or replaced text: not typing, so it counts against accuracy.
      keystrokes += next.length - typed.length;
      mistakes += next.length - typed.length;
    }
    typed = next;
    if (typed == target) _finished = now;
  }

  /// The index of the first wrong letter, or -1 when everything typed matches.
  int get firstWrong {
    for (var i = 0; i < typed.length; i++) {
      if (i >= target.length || typed[i] != target[i]) return i;
    }
    return -1;
  }

  /// The letter to type next, or null when done.
  String? get next => typed.length < target.length && firstWrong < 0
      ? target[typed.length]
      : null;

  /// Words per minute, counting five letters as a word, once finished.
  double get wpm {
    final start = _started, end = _finished;
    if (start == null || end == null) return 0;
    final minutes = math.max(end.difference(start).inMilliseconds, 500) / 60000;
    return target.length / 5 / minutes;
  }

  /// Share of keystrokes that were right, 0 to 1.
  double get accuracy =>
      keystrokes == 0 ? 1 : (keystrokes - mistakes) / keystrokes;
}

/// The result of a whole practice session.
class TypingSummary {
  TypingSummary(List<TypingRun> runs)
      : sentences = runs.length,
        wpm = runs.isEmpty
            ? 0
            : runs.map((r) => r.wpm).reduce((a, b) => a + b) / runs.length,
        accuracy = runs.isEmpty
            ? 1
            : runs.map((r) => r.accuracy).reduce((a, b) => a + b) / runs.length,
        specialTyped = runs
            .map((r) => TypingPractice.special.allMatches(r.target).length)
            .fold(0, (a, b) => a + b);

  final int sentences;
  final double wpm;
  final double accuracy;

  /// How many ä ö ü ß were typed.
  final int specialTyped;
}
