/// One gap in a cloze (Lückentext) passage, with the words to choose from.
class ClozeGap {
  const ClozeGap({required this.options, required this.answer});

  final List<String> options;
  final String answer;
}

/// The register a writing task is written in. Goethe and TestDaF both mark
/// whether the tone fits the situation: informal ("du") to a friend, formal
/// ("Sie") to an office or landlord.
enum WritingRegister { informal, formal, essay }

/// One Leitpunkt: a content point the answer must address, as in the Goethe
/// Schreiben tasks ("Sagen Sie, warum Sie nicht kommen können"). It counts as
/// covered when any of its [keywords] appears in the text.
class ContentPoint {
  const ContentPoint({required this.label, required this.keywords});

  final String label;
  final List<String> keywords;
}

/// What a writing exercise asks for and how it is assessed without AI: content
/// points covered, a fitting greeting and closing, a consistent register, and a
/// reasonable length. Grammar and vocabulary are left to the optional AI coach.
class WritingBrief {
  const WritingBrief({
    required this.minWords,
    required this.register,
    required this.points,
  });

  final int minWords;
  final WritingRegister register;
  final List<ContentPoint> points;

  bool get isLetter => register != WritingRegister.essay;
}
