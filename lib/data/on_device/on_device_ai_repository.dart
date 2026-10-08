import 'dart:convert';

import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';
import 'model_catalogue.dart';
import 'model_manager.dart';
import 'on_device_runtime.dart';

/// Thrown when the AI Coach needs a model that has not been downloaded yet.
class ModelNotInstalledException implements Exception {
  const ModelNotInstalledException(this.kind);
  final ModelKind kind;

  @override
  String toString() => switch (kind) {
        ModelKind.tutor =>
          'Download a tutor model in Account → AI & voice → On-device AI to use the coach offline.',
        ModelKind.speechRecognition =>
          'Download speech recognition in Account → AI & voice → On-device AI to speak to the coach offline.',
        ModelKind.voice =>
          'Download a voice in Account → AI & voice to hear the coach offline.',
      };
}

/// The AI Coach running entirely on the phone: no network, no server.
///
/// The prompts are shorter versions of the gateway's (small models follow a
/// few clear rules better than many), and the reply is constrained to a JSON
/// schema so it always parses.
class OnDeviceAIRepository implements AIRepository {
  OnDeviceAIRepository(this.models);

  final ModelManager models;
  OnDeviceRuntime get _runtime => models.runtime;

  OnDeviceModel _requireTutor() =>
      models.activeTutor ??
      (throw const ModelNotInstalledException(ModelKind.tutor));

  @override
  Future<CoachReply> correctGerman(String text, TutorContext context) async {
    await models.ensureLoaded();
    final raw = await _runtime.generateJson(
      _requireTutor(),
      [
        TutorMessage.system(systemPrompt(context)),
        TutorMessage.user(correctionPrompt(text)),
      ],
      jsonSchema: correctionSchema,
    );
    return parseCoachReply(raw, text);
  }

  @override
  Future<TutorReply> chat(String message, TutorContext context) async {
    await models.ensureLoaded();
    final raw = await _runtime.generateJson(
      _requireTutor(),
      [
        TutorMessage.system(systemPrompt(context)),
        TutorMessage.user(chatPrompt(message)),
      ],
      jsonSchema: chatSchema,
    );
    return parseTutorReply(raw, message);
  }

  @override
  Future<TranscriptionResult> transcribeAudio(
      AudioCapture audio, TutorContext context) async {
    await models.ensureLoaded();
    final model = models.activeSpeechModel ??
        (throw const ModelNotInstalledException(ModelKind.speechRecognition));
    final text = await _runtime.transcribe(model, audio.bytes);
    if (text.isEmpty) throw Exception('No speech was detected.');
    return TranscriptionResult(text: text, language: 'de');
  }

  @override
  Future<SpeechAudio> synthesizeSpeech(String text, TutorContext context,
      {String? voice, int? speechRate}) async {
    await models.ensureLoaded();
    final model = models.voiceFor(voice) ??
        (throw const ModelNotInstalledException(ModelKind.voice));
    final bytes = await _runtime.synthesize(model, text,
        lengthScale: lengthScaleFor(speechRate));
    return SpeechAudio(bytes,
        voiceUsed: model.id, usedFallback: voice != null && voice != model.id);
  }

  @override
  Future<VoiceList> listVoices() async {
    await models.ensureLoaded();
    return VoiceList(
      defaultId: models.voiceFor(null)?.id ?? defaultVoiceId,
      voices: [
        for (final v in VoiceList.offline.voices)
          if (v.isOpenSource)
            VoiceOption(
              id: v.id,
              label: v.label,
              description: v.description,
              engine: v.engine,
              license: v.license,
              quality: v.quality,
              available: models.isInstalled(v.id),
            ),
      ],
    );
  }
}

/// Piper's length scale for a speed in words per minute (larger = slower).
double lengthScaleFor(int? wpm) {
  final clamped = (wpm ?? 180).clamp(120, 260);
  return 180 / clamped;
}

String systemPrompt(TutorContext context) {
  final learner = jsonEncode({
    'level': context.level,
    if (context.unit != null) 'unit': context.unit,
    if (context.lesson != null) 'lesson': context.lesson,
    if (context.weakSkills.isNotEmpty) 'weak_skills': context.weakSkills,
    if (context.recentMistakes.isNotEmpty)
      'recent_mistakes': context.recentMistakes.take(5).toList(),
  });
  return '''
You are Sprichst, a careful German tutor. The learner is at CEFR level ${context.level}.
Learner context: $learner
Rules:
- Only correct real mistakes (verb endings, articles, case, word order, spelling, vocabulary). Never rewrite a correct sentence just to sound nicer.
- Never invent grammar rules. Keep explanations short and simple, in English.
- Use German vocabulary suitable for the learner's level.
- Answer with the requested JSON only.'''
      .trim();
}

String correctionPrompt(String text) => '''
Check this German sentence: "$text"
If it is correct: correct=true, corrected = the same sentence, explanation = "".
If not: correct=false, corrected = the sentence with only the mistakes fixed, explanation = one short English sentence naming each mistake and its fix.
followUp = one short, simple German question to keep practising.
Example: "Ich habe ein Hund." → corrected "Ich habe einen Hund.", explanation "Hund is masculine and the object of haben, so it is accusative: ein → einen."''';

String chatPrompt(String message) => '''
The learner wrote: "$message"
corrected = the learner's sentence with only real mistakes fixed (exactly the same sentence if it has none).
explanation = if you changed something, one short English sentence saying what and why; otherwise "".
reply = a short, friendly answer in simple German that continues the conversation.
followUp = exactly one simple German question.
Example: "Ich gehen morgen zur Arbeit." → corrected "Ich gehe morgen zur Arbeit.", explanation "With 'ich', gehen becomes gehe."''';

const correctionSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'correct': {'type': 'boolean'},
    'corrected': {'type': 'string'},
    'explanation': {'type': 'string'},
    'followUp': {'type': 'string'},
  },
  'required': ['correct', 'corrected', 'explanation', 'followUp'],
};

// Property order is generation order: the model settles the corrected
// sentence before it writes a reply (otherwise small models tend to fold the
// correction into the reply and leave the correction empty).
const chatSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'corrected': {'type': 'string'},
    'explanation': {'type': 'string'},
    'reply': {'type': 'string'},
    'followUp': {'type': 'string'},
  },
  'required': ['corrected', 'explanation', 'reply', 'followUp'],
};

Map<String, dynamic> _decode(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('The tutor model did not return an answer.');
  }
  return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
}

/// Share of [original]'s words still in [rewrite]. A real correction keeps
/// most of the learner's words; a translation or a new sentence does not.
double keptWords(String original, String rewrite) {
  final before = _normalise(original).split(' ').where((w) => w.isNotEmpty);
  final after = _normalise(rewrite).split(' ').toSet();
  if (before.isEmpty) return 0;
  return before.where(after.contains).length / before.length;
}

String _normalise(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

CoachReply parseCoachReply(String raw, String original) {
  final data = _decode(raw);
  final corrected = (data['corrected'] as String?)?.trim();
  // A "correction" that drops most of the learner's words is not one.
  final fixed = corrected == null ||
          corrected.isEmpty ||
          keptWords(original, corrected) < 0.5
      ? original
      : corrected;
  // Small models sometimes say "incorrect" but return the same sentence, or
  // "correct" while changing it: what they changed is what counts.
  final unchanged = _normalise(fixed) == _normalise(original);
  final explanation = unchanged
      ? 'This sentence is correct.'
      : explainChange(original, fixed, data['explanation'] as String?);
  return CoachReply(
    original: original,
    corrected: unchanged ? original : fixed,
    explanation: explanation,
    followUp: (data['followUp'] as String? ?? '').trim(),
    wasCorrect: unchanged,
  );
}

/// "ein Hund → einen Hund": the words that differ between [from] and [to].
String describeChange(String from, String to) {
  final a = from.split(RegExp(r'\s+'));
  final b = to.split(RegExp(r'\s+'));
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length, endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  String strip(List<String> words) =>
      words.join(' ').replaceAll(RegExp(r'[.!?,;:]+$'), '');
  final was = strip(a.sublist(start, endA));
  final now = strip(b.sublist(start, endB));
  if (was.isEmpty) return 'Add "$now".';
  if (now.isEmpty) return 'Remove "$was".';
  return '"$was" → "$now".';
}

TutorReply parseTutorReply(String raw, String message) {
  final data = _decode(raw);
  final corrected =
      ((data['corrected'] ?? data['correction']) as String? ?? '').trim();
  // Corrected to itself (no mistake), or rewritten into something else
  // entirely, such as an English translation: not a correction.
  final isCorrection = corrected.isNotEmpty &&
      corrected.toLowerCase() != 'null' &&
      _normalise(corrected) != _normalise(message) &&
      keptWords(message, corrected) >= 0.5;
  return TutorReply(
    reply: (data['reply'] as String? ?? '').trim(),
    correction: isCorrection ? corrected : null,
    explanation: isCorrection
        ? explainChange(message, corrected, data['explanation'] as String?)
        : null,
    followUp: (data['followUp'] as String? ?? '').trim(),
  );
}

/// Always leads with exactly what changed, which is never wrong, then the
/// model's reason when it has one (small models' grammar reasons can be off,
/// so the learner can tell the fact from the explanation).
String explainChange(String from, String to, String? reason) {
  final change = describeChange(from, to);
  final why = (reason ?? '').trim();
  if (why.isEmpty || why.toLowerCase().contains('is correct')) return change;
  return '$change $why';
}
