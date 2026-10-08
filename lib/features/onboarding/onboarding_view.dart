import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  var _step = 0;
  var _language = 'English';
  var _level = CefrLevel.preA1;
  var _goal = LearningGoal.everyday;

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      body: CenteredScroll(
        child: AnimatedSwitcher(
          duration: motionDuration(context, 250),
          child: switch (_step) {
            0 => _Welcome(
                key: const ValueKey(0),
                onStart: () => setState(() => _step = 1)),
            1 => _LanguageStep(
                key: const ValueKey(1),
                selected: _language,
                onSelect: (value) => setState(() => _language = value),
                onNext: () => setState(() => _step = 2),
              ),
            2 => _LevelStep(
                key: const ValueKey(2),
                selected: _level,
                onSelect: (value) => setState(() => _level = value),
                onNext: () => setState(() => _step = 3),
              ),
            _ => _GoalStep(
                key: const ValueKey(3),
                selected: _goal,
                onSelect: (value) => setState(() => _goal = value),
                onFinish: _finish,
              ),
          },
        ),
      ),
    );
  }

  Future<void> _finish() async {
    try {
      await ref
          .read(appControllerProvider)
          .completeOnboarding(language: _language, level: _level, goal: _goal);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not save your plan. Please try again.')),
      );
    }
  }
}

/// The SPRICHST wordmark with the flag stripe beneath it.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPRICHST',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          const SizedBox(width: 96, child: FlagStripe()),
        ],
      );
}

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Wordmark(),
          const SizedBox(height: 36),
          Text('Willkommen bei\nSprichst.',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 42)),
          const SizedBox(height: 16),
          const Text(
              'Learn German from your first words to confident conversation.',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 36),
          FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Start')),
        ],
      );
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onNext});
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What language should explain German?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          for (final language in ['English', 'Hindi', 'Telugu', 'Other'])
            RadioListTile<String>(
              value: language,
              groupValue: selected,
              contentPadding: EdgeInsets.zero,
              title: Text(language),
              onChanged: (value) => onSelect(value!),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onNext, child: const Text('Continue')),
        ],
      );
}

class _LevelStep extends StatelessWidget {
  const _LevelStep(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onNext});
  final CefrLevel selected;
  final ValueChanged<CefrLevel> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where are you now?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Choose a starting point. You can change it later.'),
          const SizedBox(height: 16),
          for (final level in CefrLevel.values)
            RadioListTile<CefrLevel>(
              value: level,
              groupValue: selected,
              contentPadding: EdgeInsets.zero,
              title: Text(level.label),
              subtitle: Text(level.description),
              onChanged: (value) => onSelect(value!),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onNext, child: const Text('Continue')),
        ],
      );
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onFinish,
  });

  final LearningGoal selected;
  final ValueChanged<LearningGoal> onSelect;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What do you want German for?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Your lessons, vocabulary and practice follow this goal. You can change it any time.'),
          const SizedBox(height: 16),
          GoalPicker(selected: selected, onSelect: onSelect),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: onFinish, child: const Text('Build my learning plan')),
        ],
      );
}

/// The learning goals as selectable cards (a single choice).
class GoalPicker extends StatelessWidget {
  const GoalPicker({super.key, required this.selected, required this.onSelect});

  final LearningGoal selected;
  final ValueChanged<LearningGoal> onSelect;

  static IconData _icon(LearningGoal goal) => switch (goal) {
        LearningGoal.everyday => Icons.forum_outlined,
        LearningGoal.travel => Icons.flight_takeoff_rounded,
        LearningGoal.work => Icons.work_outline_rounded,
        LearningGoal.goethe => Icons.workspace_premium_outlined,
        LearningGoal.testdaf => Icons.school_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RadioGroup<LearningGoal>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) onSelect(value);
      },
      child: Column(
        children: [
          for (final goal in LearningGoal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: SoftCard(
                padding: EdgeInsets.zero,
                color: goal == selected ? context.softSurface : null,
                child: RadioListTile<LearningGoal>(
                  value: goal,
                  secondary: Icon(_icon(goal)),
                  title: Text(goal.label, style: theme.textTheme.titleMedium),
                  subtitle: Text(goal.description),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
