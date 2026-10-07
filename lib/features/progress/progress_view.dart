import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final weak = app.weakSkills;
    final next = app.currentLesson;
    return PageFrame(
      title: 'Your progress',
      subtitle:
          'These learning signals help Sprichst choose what to teach next. They are not CEFR certification.',
      child: ListView(children: [
        SoftCard(
          color: Theme.of(context).colorScheme.primary,
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.workspace_premium)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${profile.currentLevel.label} learner',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  Text(
                      '${profile.xp} XP · ${profile.completedLessonCount} lessons complete · ${profile.streakAt(DateTime.now())}-day streak',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ))
                ])),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Skill matrix'),
        const SizedBox(height: 12),
        SoftCard(
            child: Column(children: [
          for (final skill in profile.scores.entries.entries) ...[
            SkillMeter(label: skill.key, value: skill.value),
            const SizedBox(height: 17)
          ]
        ])),
        const SizedBox(height: 24),
        const SectionTitle('Needs attention'),
        const SizedBox(height: 12),
        SoftCard(
          child: weak.isEmpty
              ? const Text(
                  'No weak spots yet. Keep completing lessons and Sprichst will flag the skills that need more practice.')
              : Column(children: [
                  for (final skill in weak) ...[
                    SkillMeter(
                      label: _weakSkillLabel(profile, skill),
                      value: profile.skillStats[skill]!.accuracy,
                    ),
                    const SizedBox(height: 17),
                  ],
                ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Next milestone'),
        const SizedBox(height: 12),
        SoftCard(
          child: Text(next == null
              ? 'Your curriculum is loading.'
              : 'Next up: ${next.title}. ${next.objective}'),
        ),
      ]),
    );
  }

  static String _weakSkillLabel(LearningProfile profile, String skill) {
    final stat = profile.skillStats[skill]!;
    return '${skillLabel(skill)} · ${stat.correct}/${stat.attempts} correct';
  }
}
