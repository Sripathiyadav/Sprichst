import 'learning_models.dart';

/// One line of a short everyday conversation.
///
/// A partner line is just [text] (with an [english] gloss). A learner line is a
/// gap: [intent] says what to express, [options] are candidate German replies,
/// and [answer] is the one that fits.
class DialogueTurn {
  const DialogueTurn.partner({required this.text, this.english})
      : intent = null,
        options = const [],
        answer = null;

  const DialogueTurn.learner({
    required this.intent,
    required this.options,
    required this.answer,
  })  : text = '',
        english = null;

  final String text;
  final String? english;
  final String? intent;
  final List<String> options;
  final String? answer;

  bool get isLearner => answer != null;
}

/// A situational dialogue in the spirit of the Goethe Sprechen and Hören tasks:
/// ordering at a bakery, introducing yourself, making an appointment.
class Dialogue {
  const Dialogue({
    required this.id,
    required this.title,
    required this.level,
    required this.topics,
    required this.turns,
  });

  final String id;
  final String title;
  final CefrLevel level;
  final List<String> topics;
  final List<DialogueTurn> turns;

  int get gapCount => turns.where((t) => t.isLearner).length;
}
