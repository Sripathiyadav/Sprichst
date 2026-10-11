import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../../domain/learning/exercise_evaluator.dart';
import '../../../domain/learning/writing_assessor.dart';
import '../../../domain/models/learning_models.dart';
import '../../../shared/haptics.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../ai_coach/services/audio_recorder_service.dart';
import 'exercise_widgets.dart';

/// The text a task is about: a notice, an email, a short dialogue. Exam reading
/// tasks always present the text first, then the questions.
class PassageCard extends StatelessWidget {
  const PassageCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: SoftCard(
        color: context.softSurface,
        child: Semantics(
          label: 'Text: $text',
          excludeSemantics: true,
          child: Text(text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
        ),
      ),
    );
  }
}

/// A small label naming the exam task an exercise imitates ("Lesen Teil 1").
class ExamPartTag extends StatelessWidget {
  const ExamPartTag(this.part, {super.key});

  final String part;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: const Icon(Icons.assignment_outlined, size: 18),
          label: Text(part),
          visualDensity: VisualDensity.compact,
        ),
      );
}

/// Lückentext: a passage with numbered gaps, each filled from a few options.
class ClozeInput extends StatefulWidget {
  const ClozeInput({
    super.key,
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  State<ClozeInput> createState() => _ClozeInputState();
}

class _ClozeInputState extends State<ClozeInput> {
  late final List<String?> _chosen =
      List.filled(widget.exercise.gaps.length, null);

  static final _marker = RegExp(r'\{(\d+)\}');

  void _pick(int gap, String option) {
    Haptics.selection();
    setState(() => _chosen[gap] = option);
    widget.onResponse(_chosen.every((c) => c != null)
        ? _chosen.join(ExerciseEvaluator.gapSeparator)
        : null);
  }

  /// The passage with each gap shown as its current choice, or its number.
  List<InlineSpan> _passage(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.exercise.context ?? '';
    final locked = widget.result != null;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _marker.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(cursor, m.start)));
      final gap = int.parse(m.group(1)!) - 1;
      final value = gap < _chosen.length ? _chosen[gap] : null;
      final right = locked &&
          value != null &&
          gap < widget.exercise.gaps.length &&
          value == widget.exercise.gaps[gap].answer;
      spans.add(TextSpan(
        text: value == null ? ' ( ${gap + 1} ) ' : ' $value ',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: !locked
              ? context.accent
              : right
                  ? context.onSuccessSurface
                  : theme.colorScheme.error,
          decoration: locked && !right ? TextDecoration.lineThrough : null,
          backgroundColor: right ? context.successSurface : null,
        ),
      ));
      cursor = m.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.result != null;
    final gaps = widget.exercise.gaps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SoftCard(
            color: context.softSurface,
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                children: _passage(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var g = 0; g < gaps.length; g++) ...[
          Text('Gap ${g + 1}', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in gaps[g].options)
                ChoiceChip(
                  label: Text(option),
                  selected: _chosen[g] == option,
                  showCheckmark: true,
                  onSelected: locked ? null : (_) => _pick(g, option),
                  labelStyle: theme.textTheme.titleMedium,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Hören: the text is read aloud (through the tutor gateway). A transcript is
/// always one tap away, and opens by itself once the answer is checked, so the
/// task still works without audio.
class ListeningInput extends StatefulWidget {
  const ListeningInput({
    super.key,
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  State<ListeningInput> createState() => _ListeningInputState();
}

class _ListeningInputState extends State<ListeningInput> {
  var _showTranscript = false;

  @override
  Widget build(BuildContext context) {
    final transcript = widget.exercise.audioText ?? '';
    final open = _showTranscript || widget.result != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SpeakButton(text: transcript, label: 'Play audio', filled: true),
            if (widget.result == null)
              TextButton(
                onPressed: () =>
                    setState(() => _showTranscript = !_showTranscript),
                child: Text(open ? 'Hide transcript' : 'Show transcript'),
              ),
          ],
        ),
        if (open) ...[
          const SizedBox(height: AppSpacing.xs),
          PassageCard(text: transcript),
        ],
        const SizedBox(height: AppSpacing.md),
        MultipleChoiceInput(
          exercise: widget.exercise,
          onResponse: widget.onResponse,
          result: widget.result,
        ),
      ],
    );
  }
}

/// Schreiben: a free text with a live word count and a checklist of the content
/// points (Leitpunkte) the task asks for, ticked as the text covers them.
class WritingInput extends ConsumerStatefulWidget {
  const WritingInput({
    super.key,
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  ConsumerState<WritingInput> createState() => _WritingInputState();
}

class _WritingInputState extends ConsumerState<WritingInput> {
  static const _assessor = WritingAssessor();

  final _controller = TextEditingController();
  WritingAssessment? _live;
  CoachReply? _coach;
  var _asking = false;

  WritingBrief get _brief => widget.exercise.brief!;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() =>
        _live = value.trim().isEmpty ? null : _assessor.assess(value, _brief));
    widget.onResponse(value.trim().isEmpty ? null : value);
  }

  Future<void> _askTutor() async {
    setState(() => _asking = true);
    try {
      final reply =
          await ref.read(appControllerProvider).correctGerman(_controller.text);
      if (mounted) setState(() => _coach = reply);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The tutor is not available right now.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.result != null;
    final words = _live?.wordCount ?? 0;
    final enough = words >= _brief.minWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _brief.isLetter
              ? 'Content points (Leitpunkte)'
              : 'Cover these points',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xxs),
        for (var i = 0; i < _brief.points.length; i++)
          _CheckRow(
            label: _brief.points[i].label,
            done: _live?.pointsCovered[i] ?? false,
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          readOnly: locked,
          minLines: 7,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodyLarge,
          decoration: const InputDecoration(
            labelText: 'Your text',
            alignLabelWithHint: true,
          ),
          onChanged: _changed,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(enough ? Icons.check_circle : Icons.edit_note,
                  size: 20,
                  color: enough ? context.accent : theme.colorScheme.outline),
              const SizedBox(width: AppSpacing.xxs),
              Text('$words / ${_brief.minWords} words',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        if (locked) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Model answer', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          PassageCard(text: widget.exercise.answer),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _asking ? null : _askTutor,
            icon: _asking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Ask the AI tutor to correct it'),
          ),
          if (_coach != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_coach!.corrected, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_coach!.explanation),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label, ${done ? 'covered' : 'not yet covered'}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: done
                    ? context.accent
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      );
}

/// Sprechen: say the target out loud. The clip is transcribed by the tutor
/// gateway and compared with the target. The transcript can be edited, and
/// typing instead is always possible, so the task never depends on a
/// microphone.
class SpeakingInput extends ConsumerStatefulWidget {
  const SpeakingInput({
    super.key,
    required this.exercise,
    required this.onResponse,
    required this.result,
  });

  final Exercise exercise;
  final ValueChanged<String?> onResponse;
  final ExerciseResult? result;

  @override
  ConsumerState<SpeakingInput> createState() => _SpeakingInputState();
}

class _SpeakingInputState extends ConsumerState<SpeakingInput> {
  final _recorder = AudioRecorderService();
  final _controller = TextEditingController();
  var _recording = false;
  var _transcribing = false;

  @override
  void dispose() {
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle() async {
    if (_transcribing) return;
    if (_recording) return _stop();
    try {
      if (!await _recorder.hasPermission()) {
        _say('Microphone access is off. You can type your answer instead.');
        return;
      }
      await _recorder.start();
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      _say(
          'The microphone is not available. You can type your answer instead.');
    }
  }

  Future<void> _stop() async {
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    try {
      final audio = await _recorder.stop();
      if (audio == null) throw StateError('no audio');
      final app = ref.read(appControllerProvider);
      final result = await ref.read(aiRepositoryProvider).transcribeAudio(
            AudioCapture(
              bytes: audio.bytes,
              filename: audio.filename,
              mimeType: audio.mimeType,
            ),
            app.tutorContext,
          );
      final text = result.text.trim();
      if (text.isEmpty) throw StateError('no speech');
      if (!mounted) return;
      _controller.text = text;
      widget.onResponse(text);
    } catch (_) {
      _say('We could not hear that. Try again, or type your answer.');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.result != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: _recording ? 'Stop recording' : 'Start recording',
            excludeSemantics: true,
            onTap: locked ? null : _toggle,
            child: SizedBox(
              width: 96,
              height: 96,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: _recording
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  foregroundColor: _recording
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onPrimary,
                ),
                onPressed: locked || _transcribing ? null : _toggle,
                child: _transcribing
                    ? const CircularProgressIndicator()
                    : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 44),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            _transcribing
                ? 'Listening to your recording…'
                : _recording
                    ? 'Recording — tap to stop'
                    : 'Tap the microphone and speak',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          readOnly: locked,
          autocorrect: false,
          enableSuggestions: false,
          style: theme.textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: 'What we heard (or type your answer)',
          ),
          onChanged: (v) => widget.onResponse(v.trim().isEmpty ? null : v),
        ),
      ],
    );
  }
}
