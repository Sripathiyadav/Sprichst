import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/on_device/model_catalogue.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'intro_tour.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  var _step = 0;
  var _level = CefrLevel.preA1;

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelManagerProvider);
    // In a browser there is no model to download, so the level is the last step.
    final steps = models.isSupported ? 2 : 1;
    return GlassPage(
      body: CenteredScroll(
        child: AnimatedSwitcher(
          duration: motionDuration(context, 250),
          child: switch (_step) {
            0 => _Welcome(
                key: const ValueKey(0),
                onStart: () => setState(() => _step = 1)),
            1 => _LevelStep(
                key: const ValueKey(1),
                steps: steps,
                selected: _level,
                onSelect: (value) => setState(() => _level = value),
                onNext: steps == 1 ? _finish : () => setState(() => _step = 2),
              ),
            _ => _ModelStep(key: const ValueKey(2), onFinish: _finish),
          },
        ),
      ),
    );
  }

  /// The goal starts as everyday German; it can be changed in Account.
  Future<void> _finish() async {
    try {
      await ref.read(appControllerProvider).completeOnboarding(level: _level);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not save your plan. Please try again.')),
      );
    }
  }
}

/// The first screen: the name, then the tour animation with its words.
class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(size: 32),
          const SizedBox(height: AppSpacing.md),
          Text('Willkommen bei Sprichst.',
              locale: const Locale('de'),
              style: Theme.of(context).textTheme.headlineMedium),
          Text('More languages coming soon.',
              key: const ValueKey('welcome-more-languages'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.tokens.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          IntroTour(finishLabel: 'Start', onDone: onStart),
        ],
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader(
      {required this.step,
      required this.steps,
      required this.title,
      this.hint});

  final int step;
  final int steps;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillMeter(
            label: 'STEP $step OF $steps',
            value: step / steps,
            valueLabel: '$step / $steps',
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

class _LevelStep extends StatelessWidget {
  const _LevelStep(
      {super.key,
      required this.steps,
      required this.selected,
      required this.onSelect,
      required this.onNext});
  final int steps;
  final CefrLevel selected;
  final ValueChanged<CefrLevel> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
              step: 1,
              steps: steps,
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

/// Puts the coach on the phone. The download carries on in the background
/// after onboarding (Coach shows its progress), so nobody waits here for
/// gigabytes. Skipping is fine: a model or an AI key can be added any time.
class _ModelStep extends ConsumerWidget {
  const _ModelStep({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelManagerProvider)..ensureLoaded();
    final tutor = models.recommendedTutorModel;
    final installed = models.isInstalled(tutor.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
            step: 2,
            steps: 2,
            title: 'Put the coach on this phone',
            hint:
                'Download it once. Then the coach works offline and nothing you say leaves your phone.'),
        SoftCard(
          child: Row(children: [
            const Icon(Icons.phone_android),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                  '${tutor.label} · ${formatBytes(tutor.downloadBytes)}'
                  '${installed ? ' · on this phone' : ''}',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Best on Wi-Fi. You can keep learning while it downloads.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.tokens.inkMuted)),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          key: const ValueKey('download-coach'),
          label: installed ? 'Continue' : 'Download and start',
          block: true,
          onPressed: () {
            if (!installed) unawaited(models.download(tutor.id));
            onFinish();
          },
        ),
        if (!installed) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              key: const ValueKey('skip-download'),
              onPressed: onFinish,
              child: const Text('Not now — I’ll use my own AI key'),
            ),
          ),
        ],
      ],
    );
  }
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
