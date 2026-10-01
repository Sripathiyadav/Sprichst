import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    return PageFrame(
      title: 'Your progress',
      subtitle:
          'These learning signals help Sprichst choose what to teach next. They are not CEFR certification.',
      child: ListView(children: [
        SoftCard(
          color: SprichstTheme.forest,
          child: Row(children: [
            const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.workspace_premium, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${profile.currentLevel.label} learner',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  Text(
                      '${profile.xp} XP · ${profile.completedLessonIds.length} lessons complete · ${profile.streak}-day streak',
                      style: const TextStyle(color: Colors.white70))
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
        const SectionTitle('Next milestone'),
        const SizedBox(height: 12),
        const SoftCard(
            child: Text(
                'Build a steady foundation in greetings, introductions, pronunciation, and common nouns. Once retention is strong, Sprichst will unlock the next unit.')),
      ]),
    );
  }
}
