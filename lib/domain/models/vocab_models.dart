/// One vocabulary entry, the unit of a flashcard.
///
/// [german] is the word without its article; nouns carry [article] separately
/// so cards can teach the article together with the noun and games can ask for
/// it on its own.
class VocabItem {
  const VocabItem({
    required this.id,
    required this.german,
    required this.english,
    this.article,
    this.example,
    this.exampleEnglish,
  });

  /// Stable across releases: `<lessonId>/<slug of german>`.
  final String id;
  final String german;
  final String english;
  final String? article;
  final String? example;
  final String? exampleEnglish;

  bool get isNoun => article != null;

  /// How the word is written on a card: "der Tisch", "lernen".
  String get display => article == null ? german : '$article $german';
}

/// The schedule of one flashcard: an SM-2 style state. [ease] is how quickly the
/// interval grows after a successful recall; [lapses] counts how often the card
/// was forgotten.
class CardState {
  const CardState({
    required this.dueAt,
    this.intervalDays = 0,
    this.ease = defaultEase,
    this.reps = 0,
    this.lapses = 0,
  });

  static const defaultEase = 2.5;
  static const minEase = 1.3;

  final DateTime dueAt;
  final int intervalDays;
  final double ease;
  final int reps;
  final int lapses;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  /// Cards reviewed successfully across weeks are "mature"; the rest are still
  /// being learned.
  bool get isMature => intervalDays >= 21;
}

/// Everything about a learner's flashcards that must persist.
class FlashcardProgress {
  const FlashcardProgress({
    this.states = const {},
    this.day,
    this.newToday = 0,
  });

  final Map<String, CardState> states;

  /// The calendar day (`yyyy-MM-dd`) [newToday] counts, so the daily limit of new
  /// cards resets on its own.
  final String? day;
  final int newToday;

  FlashcardProgress copyWith({
    Map<String, CardState>? states,
    String? day,
    int? newToday,
  }) =>
      FlashcardProgress(
        states: states ?? this.states,
        day: day ?? this.day,
        newToday: newToday ?? this.newToday,
      );
}
