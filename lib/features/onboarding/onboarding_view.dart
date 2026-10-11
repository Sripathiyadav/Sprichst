import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/lottie_view.dart';
import 'intro_tour.dart';

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
            1 => IntroTour(
                key: const ValueKey(1),
                onDone: () => setState(() => _step = 2),
              ),
            2 => _LanguageStep(
                key: const ValueKey(2),
                selected: _language,
                onSelect: (value) => setState(() => _language = value),
                onNext: () => setState(() => _step = 3),
              ),
            3 => _LevelStep(
                key: const ValueKey(3),
                selected: _level,
                onSelect: (value) => setState(() => _level = value),
                onNext: () => setState(() => _step = 4),
              ),
            _ => _GoalStep(
                key: const ValueKey(4),
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

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(size: 32),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: SprichstLottie('welcome_intro', width: 200, height: 200),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Willkommen bei\nSprichst.',
              locale: const Locale('de'),
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.md),
          Text('Learn German from your first words to confident conversation.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(label: 'Start', onPressed: onStart),
          const SizedBox(height: AppSpacing.xs),
          Text('A quick tour of how it works, then three questions.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.tokens.inkMuted)),
        ],
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.hint});

  final int step;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillMeter(
            label: 'STEP $step OF 3',
            value: step / 3,
            valueLabel: '$step / 3',
            compact: true),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(hint!,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: context.tokens.inkMuted)),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
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
          const _StepHeader(
              step: 1, title: 'What language should explain German?'),
          for (final language in ['English', 'Hindi', 'Telugu', 'Other'])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                label: language,
                state: language == selected
                    ? OptionState.selected
                    : OptionState.idle,
                onTap: () => onSelect(language),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Continue', onPressed: onNext, block: true),
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
          const _StepHeader(
              step: 2,
              title: 'Where are you now?',
              hint: 'Choose a starting point. You can change it later.'),
          for (final level in CefrLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                label: level.label,
                subtitle: level.description,
                state:
                    level == selected ? OptionState.selected : OptionState.idle,
                onTap: () => onSelect(level),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Continue', onPressed: onNext, block: true),
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
          const _StepHeader(
              step: 3,
              title: 'What do you want German for?',
              hint:
                  'Your lessons, vocabulary and practice follow this goal. You can change it any time.'),
          GoalPicker(selected: selected, onSelect: onSelect),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
              label: 'Build my learning plan',
              onPressed: onFinish,
              block: true),
        ],
      );
}

/// The learning goals as selectable tiles (a single choice).
class GoalPicker extends StatelessWidget {
  const GoalPicker({super.key, required this.selected, required this.onSelect});

  final LearningGoal selected;
  final ValueChanged<LearningGoal> onSelect;

  static IconData _icon(LearningGoal goal) => switch (goal) {
        LearningGoal.everyday => Icons.forum_outlined,
        LearningGoal.travel => Icons.flight_takeoff,
        LearningGoal.work => Icons.work_outline,
        LearningGoal.goethe => Icons.workspace_premium_outlined,
        LearningGoal.testdaf => Icons.school_outlined,
      };

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final goal in LearningGoal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                label: goal.label,
                subtitle: goal.description,
                leading: _icon(goal),
                state:
                    goal == selected ? OptionState.selected : OptionState.idle,
                onTap: () => onSelect(goal),
              ),
            ),
        ],
      );
}
