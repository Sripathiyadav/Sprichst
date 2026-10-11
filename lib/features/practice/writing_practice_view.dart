import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/typing_practice.dart';
import '../../shared/widgets/app_widgets.dart';

/// Opens a typing session built from the learner's lessons.
void openWritingPractice(BuildContext context, WidgetRef ref) {
  final app = ref.read(appControllerProvider);
  final sentences = TypingPractice.pick(
    app.curriculum,
    app.profile!.currentLevel,
    seed: DateTime.now().millisecondsSinceEpoch,
  );
  if (sentences.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No sentences to type yet. Start a lesson first.')));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => WritingPracticeView(sentences: sentences),
  ));
}

/// Writing practice: copy German sentences with ä ö ü ß, with the German keys
/// at hand, and see speed and accuracy. The goal is typing German quickly, so
/// a sentence is only finished when every letter, umlauts included, is right.
class WritingPracticeView extends StatefulWidget {
  const WritingPracticeView({super.key, required this.sentences});

  final List<TypingSentence> sentences;

  @override
  State<WritingPracticeView> createState() => _WritingPracticeViewState();
}

class _WritingPracticeViewState extends State<WritingPracticeView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late TypingRun _run = TypingRun(widget.sentences.first.german);
  final _done = <TypingRun>[];
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _allDone => _index >= widget.sentences.length;

  void _changed(String value) {
    setState(() => _run.update(value, DateTime.now()));
  }

  /// A German key was pressed: it goes in at the cursor.
  void _insert(String letter) {
    final v = _controller.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, letter);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + letter.length),
    );
    _changed(text);
    _focus.requestFocus();
  }

  void _next() {
    _done.add(_run);
    _controller.clear();
    setState(() {
      _index++;
      if (!_allDone) _run = TypingRun(widget.sentences[_index].german);
    });
    if (!_allDone) _focus.requestFocus();
  }

  void _again() {
    final app = ProviderScope.containerOf(context).read(appControllerProvider);
    final fresh = TypingPractice.pick(
      app.curriculum,
      app.profile!.currentLevel,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => WritingPracticeView(
          sentences: fresh.isEmpty ? widget.sentences : fresh),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      appBar: const MastheadBar(eyebrow: 'Writing practice'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _allDone ? _summary(context) : _sentence(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sentence(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final sentence = widget.sentences[_index];
    final run = _run;
    final wrongAt = run.firstWrong;
    final next = run.next;

    final spans = <InlineSpan>[];
    for (var i = 0; i < run.target.length; i++) {
      final typedHere = i < run.typed.length;
      final wrong = typedHere && run.typed[i] != run.target[i];
      spans.add(TextSpan(
        text: run.target[i],
        style: TextStyle(
          color: !typedHere
              ? t.inkMuted
              : wrong
                  ? t.danger
                  : t.success,
          decoration: wrong ? TextDecoration.underline : null,
          decorationColor: t.danger,
          backgroundColor:
              i == run.typed.length && !run.finished ? t.accentSoft : null,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkillMeter(
                  label: 'Sentence ${_index + 1} of ${widget.sentences.length}',
                  value: _index / widget.sentences.length,
                  valueLabel: '${_index + 1} / ${widget.sentences.length}',
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('TYPE THIS IN GERMAN', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  label: 'Type: ${sentence.german}',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(children: spans),
                    key: const ValueKey('typing-target'),
                    locale: const Locale('de'),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(sentence.english,
                    key: const ValueKey('typing-english'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: t.inkMuted, fontStyle: FontStyle.italic)),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const ValueKey('typing-field'),
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  readOnly: run.finished,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false, // typing, not pasting
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  onChanged: _changed,
                  onSubmitted: (_) {
                    if (run.finished) _next();
                  },
                  contextMenuBuilder: null,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(run.target.length + 8),
                  ],
                  decoration: const InputDecoration(labelText: 'Your typing'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _GermanKeys(onKey: _insert, highlight: next),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const ValueKey('typing-status'),
                    run.finished
                        ? 'Done: ${run.wpm.round()} words per minute, ${(run.accuracy * 100).round()}% accurate.'
                        : wrongAt >= 0
                            ? 'Letter ${wrongAt + 1} is not right: delete it and type ${run.target[wrongAt] == ' ' ? 'a space' : '“${run.target[wrongAt]}”'}.'
                            : next != null &&
                                    TypingPractice.special.hasMatch(next)
                                ? 'Next: $next. Use the key above, or your keyboard’s German layout.'
                                : run.started
                                    ? 'Keep going.'
                                    : 'Start typing. The timer starts with your first letter.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: run.finished
                            ? t.success
                            : wrongAt >= 0
                                ? t.danger
                                : t.inkMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _KeyboardTips(),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const ValueKey('typing-next'),
          label: _index == widget.sentences.length - 1
              ? 'See my results'
              : 'Next sentence',
          block: true,
          onPressed: run.finished ? _next : null,
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final s = TypingSummary(_done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Writing practice', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  header: true,
                  child: Text('Schön getippt!',
                      locale: const Locale('de'),
                      style: theme.textTheme.displaySmall),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.speed,
                        value: s.wpm.round().toString(),
                        label: 'Words per minute',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.check_circle_outline,
                        value: '${(s.accuracy * 100).round()}%',
                        label: 'Accuracy',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${s.sentences} sentences, with ${s.specialTyped} German letters (ä ö ü ß) typed.',
                  key: const ValueKey('typing-summary'),
                  style: theme.textTheme.bodyLarge?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
            key: const ValueKey('typing-again'),
            label: 'Practise again',
            block: true,
            onPressed: _again),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// ä ö ü ß and the capitals as keys. The one that is needed next is marked, so
/// the learner connects each letter with its key.
class _GermanKeys extends StatelessWidget {
  const _GermanKeys({required this.onKey, required this.highlight});

  final ValueChanged<String> onKey;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final key in TypingPractice.keys)
          Semantics(
            button: true,
            label: 'Insert $key',
            excludeSemantics: true,
            child: SizedBox(
              width: 48,
              height: 48,
              child: FilledButton.tonal(
                key: ValueKey('key-$key'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      highlight == key ? t.accentSoft : t.surfaceSunken,
                  side: BorderSide(
                      color: highlight == key ? t.accent : t.lineStrong,
                      width: highlight == key ? 2 : 1),
                ),
                onPressed: () => onKey(key),
                child: Text(key,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }
}

/// How to type these letters on a real keyboard, because the keys here are for
/// practice and the goal is to type them without help.
class _KeyboardTips extends StatelessWidget {
  const _KeyboardTips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: const ValueKey('typing-tips'),
      tilePadding: EdgeInsets.zero,
      title: Text('How to type ä ö ü ß on a keyboard',
          style: theme.textTheme.titleSmall),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Tip('Phone',
            'Hold the letter (a, o, u, s) and slide to ä, ö, ü, ß. Or add the German keyboard in Settings.'),
        _Tip('Mac',
            'Hold ⌥, press U, release, then a, o or u for ä, ö, ü. ⌥ + S gives ß.'),
        _Tip('Windows',
            'Add the German keyboard in Settings → Time & language, or hold Alt and type 0228 (ä), 0246 (ö), 0252 (ü), 0223 (ß).'),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.where, this.how);

  final String where;
  final String how;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$where: ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: how),
        ])),
      );
}
