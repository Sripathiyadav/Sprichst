import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/ai/groq_ai_repository.dart';
import '../../data/ai/groq_settings.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../shared/widgets/app_widgets.dart';

/// Checks a Groq key with Groq. Replaced in tests so no network is needed.
final groqKeyCheckerProvider =
    Provider<Future<ProviderProblem?> Function(String key)>((ref) {
  return (key) =>
      GroqAIRepository(settings: ref.read(groqSettingsProvider)).verifyKey(key);
});

/// Account → AI & voice → Groq: the learner's own free Groq account.
class GroqKeySection extends ConsumerStatefulWidget {
  const GroqKeySection({super.key});

  @override
  ConsumerState<GroqKeySection> createState() => _GroqKeySectionState();
}

class _GroqKeySectionState extends ConsumerState<GroqKeySection> {
  final _controller = TextEditingController();
  var _checking = false;
  var _hidden = true;
  String? _result;
  var _resultOk = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final settings = ref.read(groqSettingsProvider);
    final key = GroqSettings.validKey(_controller.text);
    if (key == null) {
      setState(() {
        _resultOk = false;
        _result =
            'That does not look like a Groq key. It starts with "gsk_" and has no spaces.';
      });
      return;
    }
    setState(() {
      _checking = true;
      _result = null;
    });
    final problem = await ref.read(groqKeyCheckerProvider)(key);
    if (!mounted) return;

    if (problem == ProviderProblem.invalidKey) {
      setState(() {
        _checking = false;
        _resultOk = false;
        _result = 'Groq did not accept this key. Check it and try again.';
      });
      return;
    }
    final stored = await settings.saveKey(key);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _checking = false;
      _resultOk = stored;
      _result = !stored
          ? 'The key could not be stored safely on this device.'
          : problem == null
              ? 'Connected. Your key is saved on this device only.'
              : 'Your key is saved, but Groq could not be reached to check it. It will be checked the first time you use it.';
    });
  }

  Future<void> _remove() async {
    final settings = ref.read(groqSettingsProvider);
    final confirmed = await showSprichstConfirmation(
      context,
      title: 'Remove your Groq key?',
      message:
          'The key is deleted from this device. You can add it again later. To stop it working anywhere, delete it at console.groq.com.',
      confirmLabel: 'Remove key',
      destructive: true,
    );
    if (!confirmed) return;
    await settings.removeKey();
    if (!mounted) return;
    setState(() {
      _result = 'Key removed from this device.';
      _resultOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(groqSettingsProvider);

    return SettingsSection(
      title: 'Groq (your own free account)',
      description:
          'Optional. Groq gives free accounts a daily allowance, so you get faster and more accurate answers until it runs out; then you choose whether to continue on this phone. '
          'Sprichst has no server: your messages go from this device straight to Groq under your own account, and the key never leaves this device. '
          'Anyone who can unlock your phone could use the key, so you can revoke it any time at console.groq.com.',
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.hasKey)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: context.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('Key saved: ${settings.maskedKey}',
                          key: const ValueKey('groq-key-status')),
                    ),
                    TextButton(
                      key: const ValueKey('groq-remove'),
                      onPressed: _remove,
                      child: const Text('Remove'),
                    ),
                  ],
                )
              else
                Text(
                  '1. Create a free account at console.groq.com.\n'
                  '2. Open API Keys and create a key.\n'
                  '3. Paste it below.',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('groq-key-field'),
                controller: _controller,
                obscureText: _hidden,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveAndTest(),
                decoration: InputDecoration(
                  labelText: settings.hasKey ? 'Replace key' : 'Groq API key',
                  hintText: 'gsk_…',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show key' : 'Hide key',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('groq-save'),
                onPressed: _checking ? null : _saveAndTest,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.vpn_key_outlined),
                label: const Text('Save and test'),
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _result!,
                    key: const ValueKey('groq-result'),
                    style: TextStyle(
                        color: _resultOk
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Model', style: theme.textTheme.titleSmall),
              for (final model in groqModels)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: model.id,
                  groupValue: settings.model,
                  title: Text(model.label),
                  subtitle: Text(model.note),
                  onChanged: (id) {
                    if (id != null) settings.setModel(id);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
