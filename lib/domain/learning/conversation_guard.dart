import '../models/learning_models.dart';

/// Keeps the tutor's questions moving the conversation forward.
///
/// Language models, small ones especially, fall back on the same stock
/// question ("Wie heißt du?") because each request used to be answered with no
/// memory of the last. The app now sends the recent turns, and this guard is
/// the safety net behind that: if the question the model chose was already
/// asked, or only restates one, it is replaced by a fresh one that suits the
/// learner's level. It also makes sure a reply carries one question, not two.
class ConversationGuard {
  const ConversationGuard();

  /// Turns kept and sent to the tutor: four exchanges is enough to avoid
  /// repeating itself without growing the prompt on a small phone.
  static const maxTurns = 8;

  TutorReply freshen(
    TutorReply reply,
    List<ConversationTurn> history, {
    required String level,
  }) {
    final sentences = _sentences(reply.reply);
    final statements = [
      for (final s in sentences)
        if (!s.endsWith('?')) s,
    ];
    final candidates = [
      for (final s in sentences)
        if (s.endsWith('?')) s,
      // A follow-up that is not a question is not one: small models sometimes
      // repeat the reply there.
      if (reply.followUp.trim().endsWith('?')) reply.followUp.trim(),
    ];

    final asked = askedQuestions(history);
    final nameKnown = learnerGaveName(history);

    String? chosen;
    for (final candidate in candidates) {
      if (!repeats(candidate, asked, nameKnown: nameKnown)) {
        chosen = candidate;
        break;
      }
    }
    // The model translated its own question; a question taken from our list
    // brings its own translation. Any other chosen question has none.
    String translation;
    if (chosen == null) {
      chosen = _fallback(level, asked, nameKnown, history);
      translation = translationOf(chosen);
    } else if (chosen == reply.followUp.trim()) {
      translation = reply.followUpTranslation.trim();
    } else {
      translation = '';
    }

    return TutorReply(
      reply: statements.join(' '),
      correction: reply.correction,
      explanation: reply.explanation,
      followUp: chosen,
      followUpTranslation: translation,
    );
  }

  /// The English for one of [conversationStarters]; empty for any other text.
  static String translationOf(String question) {
    for (final s in conversationStarters) {
      if (s.text == question) return s.english;
    }
    return question == _openQuestion ? _openQuestionEnglish : '';
  }

  static const _openQuestion = 'Worüber möchtest du jetzt sprechen?';
  static const _openQuestionEnglish = 'What would you like to talk about now?';

  /// Every question the tutor has already put to the learner.
  List<String> askedQuestions(List<ConversationTurn> history) => [
        for (final turn in history)
          if (!turn.fromLearner)
            for (final s in _sentences(turn.text))
              if (s.endsWith('?')) s,
      ];

  static final _introduced = RegExp(
      r'\b(ich bin|ich hei(ß|ss)e|mein name ist)\b',
      caseSensitive: false);

  /// The learner has already said who they are.
  bool learnerGaveName(List<ConversationTurn> history) => history
      .any((turn) => turn.fromLearner && _introduced.hasMatch(turn.text));

  static final _asksName = RegExp(
      r'(hei(ß|ss)t du|dein name|name ist dein|wie nennst du|hei(ß|ss)en sie|ihr name)',
      caseSensitive: false);

  /// Whether [question] repeats one in [asked], is a close paraphrase of it
  /// (most of its words are the same), or asks a name that is already known
  /// or already asked.
  bool repeats(String question, List<String> asked, {required bool nameKnown}) {
    if (_asksName.hasMatch(question)) {
      if (nameKnown || asked.any(_asksName.hasMatch)) return true;
    }
    final words = _words(question);
    if (words.isEmpty) return true;
    for (final earlier in asked) {
      final other = _words(earlier);
      final shared = words.intersection(other).length;
      final all = words.union(other).length;
      if (all > 0 && shared / all >= 0.6) return true;
    }
    return false;
  }

  String _fallback(String level, List<String> asked, bool nameKnown,
      List<ConversationTurn> history) {
    final reach = _levelIndex(level);
    final options = [
      for (final q in conversationStarters)
        if (q.level <= reach) q.text,
    ];
    // Start somewhere different each turn so two fallbacks in a row differ
    // even when little has been asked.
    final turns = history.where((t) => !t.fromLearner).length;
    for (var i = 0; i < options.length; i++) {
      final candidate = options[(turns + i) % options.length];
      if (!repeats(candidate, asked, nameKnown: nameKnown)) return candidate;
    }
    // Everything at this level has been asked: the conversation is long, so
    // open it up rather than repeat.
    return _openQuestion;
  }

  static int _levelIndex(String level) {
    final upper = level.toUpperCase();
    if (upper.contains('C1')) return 5;
    if (upper.contains('B2')) return 4;
    if (upper.contains('B1')) return 3;
    if (upper.contains('A2')) return 2;
    if (upper.contains('A1') && !upper.contains('PRE')) return 1;
    return 0;
  }

  static final _split = RegExp(r'(?<=[.!?…])\s+');

  List<String> _sentences(String text) => [
        for (final s in text.trim().split(_split))
          if (s.trim().isNotEmpty) s.trim(),
      ];

  static const _filler = {'denn', 'eigentlich', 'mal', 'noch', 'auch'};

  Set<String> _words(String text) => {
        for (final w in text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
            .split(' '))
          if (w.isNotEmpty && !_filler.contains(w)) w,
      };
}

/// A question to move the conversation on, and the lowest level it suits
/// (0 = Pre-A1, 1 = A1, 2 = A2, 3 = B1, 4 = B2, 5 = C1). They span different
/// topics so the fallback does not circle one subject.
class Starter {
  const Starter(this.level, this.text, this.english);
  final int level;
  final String text;

  /// The question in English, shown under it.
  final String english;
}

const conversationStarters = <Starter>[
  Starter(0, 'Wie geht es dir heute?', 'How are you today?'),
  Starter(0, 'Woher kommst du?', 'Where are you from?'),
  Starter(0, 'Wo wohnst du?', 'Where do you live?'),
  Starter(0, 'Welche Sprachen sprichst du?', 'Which languages do you speak?'),
  Starter(0, 'Was trinkst du gern?', 'What do you like to drink?'),
  Starter(0, 'Was isst du gern?', 'What do you like to eat?'),
  Starter(0, 'Hast du Geschwister?', 'Do you have brothers or sisters?'),
  Starter(0, 'Welche Farbe magst du?', 'Which colour do you like?'),
  Starter(1, 'Was machst du am Wochenende?', 'What do you do at the weekend?'),
  Starter(1, 'Was ist dein Hobby?', 'What is your hobby?'),
  Starter(1, 'Was machst du morgens zuerst?',
      'What do you do first in the morning?'),
  Starter(1, 'Wie ist das Wetter heute bei dir?',
      'What is the weather like where you are today?'),
  Starter(1, 'Hast du ein Haustier?', 'Do you have a pet?'),
  Starter(1, 'Was isst du zum Frühstück?', 'What do you eat for breakfast?'),
  Starter(1, 'Arbeitest du oder studierst du?', 'Do you work or do you study?'),
  Starter(1, 'Wie kommst du zur Arbeit oder zur Schule?',
      'How do you get to work or to school?'),
  Starter(
      1, 'Welche Musik hörst du gern?', 'What music do you like to listen to?'),
  Starter(1, 'Wie sieht dein Zimmer aus?', 'What does your room look like?'),
  Starter(2, 'Was hast du gestern gemacht?', 'What did you do yesterday?'),
  Starter(2, 'Was möchtest du nächste Woche machen?',
      'What would you like to do next week?'),
  Starter(2, 'Wohin bist du zuletzt gereist?', 'Where did you last travel to?'),
  Starter(2, 'Was kochst du am liebsten?', 'What do you most like to cook?'),
  Starter(2, 'Warum lernst du Deutsch?', 'Why are you learning German?'),
  Starter(2, 'Wie sieht ein typischer Tag bei dir aus?',
      'What does a typical day look like for you?'),
  Starter(2, 'Welchen Sport machst du gern, und warum?',
      'Which sport do you like, and why?'),
  Starter(2, 'Was war dein schönstes Erlebnis in diesem Jahr?',
      'What was your best experience this year?'),
  Starter(3, 'Was würdest du machen, wenn du eine Woche frei hättest?',
      'What would you do if you had a week off?'),
  Starter(3, 'Was gefällt dir an deiner Stadt, und was nicht?',
      'What do you like about your city, and what don\'t you?'),
  Starter(3, 'Welchen Film oder welches Buch kannst du empfehlen?',
      'Which film or book can you recommend?'),
  Starter(3, 'Wie hat sich dein Leben in den letzten Jahren verändert?',
      'How has your life changed in the last few years?'),
  Starter(3, 'Was ist beim Deutschlernen für dich am schwierigsten?',
      'What is hardest for you when learning German?'),
  Starter(4, 'Welche Vor- und Nachteile hat es, im Homeoffice zu arbeiten?',
      'What are the advantages and disadvantages of working from home?'),
  Starter(4, 'Was denkst du über soziale Medien im Alltag?',
      'What do you think about social media in everyday life?'),
  Starter(4, 'Wie wichtig ist dir Nachhaltigkeit beim Einkaufen?',
      'How important is sustainability to you when shopping?'),
  Starter(5, 'Inwiefern prägt die Sprache, wie wir über die Welt denken?',
      'To what extent does language shape how we think about the world?'),
];
