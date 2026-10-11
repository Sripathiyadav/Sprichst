import '../models/exam_models.dart';

/// What a writing answer got right, point by point.
class WritingAssessment {
  const WritingAssessment({
    required this.wordCount,
    required this.pointsCovered,
    required this.hasGreeting,
    required this.hasClosing,
    required this.registerConsistent,
    required this.connectorCount,
    required this.score,
    required this.notes,
  });

  final int wordCount;

  /// One flag per content point of the brief, in order.
  final List<bool> pointsCovered;
  final bool hasGreeting;
  final bool hasClosing;
  final bool registerConsistent;
  final int connectorCount;

  /// 0 to 1.
  final double score;

  /// Plain-language hints on what to add or fix.
  final List<String> notes;
}

/// Assesses writing the way the Goethe and TestDaF raters begin: did the text
/// address every content point (Leitpunkt), is the form right for the situation
/// (greeting, closing, register), is it long enough, and does it connect ideas?
///
/// This is deliberately rule-based and transparent. It cannot judge grammar or
/// vocabulary; the optional AI coach covers that, and the app says so.
class WritingAssessor {
  const WritingAssessor();

  /// A pass, as in the Goethe modules, is 60%.
  static const passMark = .6;

  static const _informalGreetings = ['liebe ', 'lieber ', 'hallo', 'hi '];
  static const _formalGreetings = [
    'sehr geehrte',
    'sehr geehrter',
    'guten tag',
  ];
  static const _informalClosings = [
    'viele grüße',
    'liebe grüße',
    'herzliche grüße',
    'bis bald',
    'bis dann',
    'tschüss',
    'deine ',
    'dein ',
  ];
  static const _formalClosings = [
    'mit freundlichen grüßen',
    'freundliche grüße',
    'hochachtungsvoll',
    'beste grüße',
  ];

  /// Words that join ideas, which B1 and TestDaF writing is expected to use.
  static const _connectors = [
    'weil',
    'denn',
    'deshalb',
    'deswegen',
    'außerdem',
    'aber',
    'jedoch',
    'obwohl',
    'dass',
    'damit',
    'trotzdem',
    'dagegen',
    'einerseits',
    'andererseits',
    'zuerst',
    'danach',
    'schließlich',
    'zum beispiel',
    'erstens',
    'zweitens',
    'insgesamt',
  ];

  WritingAssessment assess(String text, WritingBrief brief) {
    final lower = text.toLowerCase();
    final words = _words(lower);
    final wordCount = words.length;

    final covered = [
      for (final point in brief.points)
        point.keywords.any((k) => lower.contains(k.toLowerCase())),
    ];
    final contentScore =
        covered.where((c) => c).length / brief.points.length.clamp(1, 1 << 20);

    final lengthScore = (wordCount / brief.minWords).clamp(0.0, 1.0);

    final informal = brief.register == WritingRegister.informal;
    final greeting = brief.isLetter &&
        _startsWithAny(
            lower.trimLeft(), informal ? _informalGreetings : _formalGreetings);
    final closing = brief.isLetter &&
        _containsAny(lower, informal ? _informalClosings : _formalClosings);

    final registerOk = switch (brief.register) {
      WritingRegister.informal => !_containsAny(
              lower, const ['sehr geehrte', 'mit freundlichen grüßen']) &&
          !_formalAddress(text),
      WritingRegister.formal =>
        !words.any(const {'du', 'dich', 'dir', 'dein', 'deine'}.contains) &&
            !_containsAny(lower, const ['hallo ', 'liebe grüße']),
      WritingRegister.essay => true,
    };

    final connectors = _connectors.where(lower.contains).length;

    // Weights follow the shape of the real criteria: content matters most, then
    // the form that fits the situation, then length. Essays swap the letter form
    // (greeting/closing) for evidence of connected argument.
    final double structure;
    final double score;
    if (brief.isLetter) {
      structure = ((greeting ? 1 : 0) + (closing ? 1 : 0)) / 2;
      score = .5 * contentScore +
          .2 * structure +
          .1 * (registerOk ? 1 : 0) +
          .2 * lengthScore;
    } else {
      structure = (connectors / 3).clamp(0.0, 1.0);
      score = .5 * contentScore + .2 * structure + .3 * lengthScore;
    }

    final notes = <String>[
      for (var i = 0; i < covered.length; i++)
        if (!covered[i]) 'Add: ${brief.points[i].label}.',
      if (wordCount < brief.minWords)
        'Write at least ${brief.minWords} words (you have $wordCount).',
      if (brief.isLetter && !greeting)
        informal
            ? 'Start with a greeting such as "Liebe Anna,".'
            : 'Start with a formal greeting such as "Sehr geehrte Damen und Herren,".',
      if (brief.isLetter && !closing)
        informal
            ? 'End with a closing such as "Viele Grüße".'
            : 'End with a closing such as "Mit freundlichen Grüßen".',
      if (brief.isLetter && !registerOk)
        informal
            ? 'Keep it informal: use "du", not "Sie".'
            : 'Keep it formal: use "Sie", not "du".',
      if (!brief.isLetter && connectors < 2)
        'Connect your ideas with words like "weil", "außerdem" or "jedoch".',
    ];

    return WritingAssessment(
      wordCount: wordCount,
      pointsCovered: covered,
      hasGreeting: greeting,
      hasClosing: closing,
      registerConsistent: registerOk,
      connectorCount: connectors,
      score: score.clamp(0.0, 1.0),
      notes: notes,
    );
  }

  static List<String> _words(String lower) => [
        for (final match in RegExp(r'[a-zäöüß]+').allMatches(lower))
          match.group(0)!,
      ];

  static bool _startsWithAny(String text, List<String> prefixes) =>
      prefixes.any(text.startsWith);

  static bool _containsAny(String text, List<String> parts) =>
      parts.any(text.contains);

  /// A capitalised "Sie" or "Ihnen" in the middle of a sentence is the formal
  /// address; a sentence-initial "Sie" is ambiguous (she/they), so it is ignored.
  static bool _formalAddress(String text) {
    final cleaned = text.replaceAll(RegExp(r'[.!?]\s+Sie\b'), '');
    return RegExp(r'\bSie\b|\bIhnen\b').hasMatch(cleaned);
  }
}
