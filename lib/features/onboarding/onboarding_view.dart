import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  var _step = 0;
  var _language = 'English';
  var _level = CefrLevel.preA1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
                _ => _LevelStep(
                    key: const ValueKey(2),
                    selected: _level,
                    onSelect: (value) => setState(() => _level = value),
                    onFinish: () => ref
                        .read(appControllerProvider)
                        .completeOnboarding(language: _language, level: _level),
                  ),
              },
            ),
          ),
        ),
      ),
    );
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
          const Text('SPRICHTS',
              style: TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  color: SprichstTheme.forest)),
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
      required this.onFinish});
  final CefrLevel selected;
  final ValueChanged<CefrLevel> onSelect;
  final VoidCallback onFinish;

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
          FilledButton(
              onPressed: onFinish, child: const Text('Build my learning plan')),
        ],
      );
}
