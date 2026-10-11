import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/ai/cloud_ai_repository.dart';
import '../../data/ai/cloud_ai_settings.dart';
import '../../data/ai/cloud_providers.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../shared/widgets/app_widgets.dart';

/// Checks a key with its provider. Replaced in tests so no network is needed.
final cloudKeyCheckerProvider = Provider<
    Future<ProviderProblem?> Function(
        CloudProvider provider, String? key, String? baseUrl)>((ref) {
  return (provider, key, baseUrl) =>
      CloudAIRepository(settings: ref.read(cloudAISettingsProvider))
          .verifyKey(provider, key, baseUrl: baseUrl);
});

/// Account → AI & voice → My own AI key: any provider the learner has an
/// account with. The key stays on this device.
class CloudProviderSection extends ConsumerStatefulWidget {
  const CloudProviderSection({super.key});

  @override
  ConsumerState<CloudProviderSection> createState() =>
      _CloudProviderSectionState();
}

class _CloudProviderSectionState extends ConsumerState<CloudProviderSection> {
  final _key = TextEditingController();
  final _url = TextEditingController();
  final _model = TextEditingController();
  var _checking = false;
  var _hidden = true;
  String? _result;
  var _resultOk = false;

  @override
  void initState() {
    super.initState();
    _url.text = ref.read(cloudAISettingsProvider).customBaseUrl ?? '';
  }

  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  void _say(String text, {required bool ok}) => setState(() {
        _checking = false;
        _resultOk = ok;
        _result = text;
      });

  Future<void> _saveAndTest() async {
    final settings = ref.read(cloudAISettingsProvider);
    final provider = settings.provider;
    final typed = _key.text.trim();
    final key = typed.isEmpty ? null : CloudAISettings.validKey(typed);

    if (typed.isNotEmpty && key == null) {
      _say(
          'That does not look like an API key. Paste it exactly as the provider showed it, with no spaces.',
          ok: false);
      return;
    }
    if (key == null && !provider.keyOptional && !settings.hasKeyFor(provider)) {
      _say('Paste your ${provider.name} API key first.', ok: false);
      return;
    }

    String? baseUrl = provider.baseUrl;
    if (provider.isCustom) {
      baseUrl = CloudAISettings.validBaseUrl(_url.text);
      if (baseUrl == null) {
        _say(
            'Enter the server address starting with https://, for example https://…/v1. Keys are never sent over plain http.',
            ok: false);
        return;
      }
    }

    setState(() {
      _checking = true;
      _result = null;
    });
    final problem = await ref.read(cloudKeyCheckerProvider)(
        provider, key ?? settings.key, baseUrl);
    if (!mounted) return;

    if (problem == ProviderProblem.invalidKey) {
      _say('${provider.name} did not accept this key. Check it and try again.',
          ok: false);
      return;
    }
    if (provider.isCustom) await settings.setCustomBaseUrl(baseUrl);
    var stored = true;
    if (key != null) stored = await settings.saveKey(key);
    if (!mounted) return;
    _key.clear();
    _say(
      !stored
          ? 'The key could not be stored safely on this device.'
          : problem == null
              ? 'Connected. Your key is saved on this device only.'
              : '${provider.name} could not be reached to check it, so the key is saved but untested. It will be checked the first time you use it.',
      ok: stored,
    );
  }

  Future<void> _remove() async {
    final settings = ref.read(cloudAISettingsProvider);
    final provider = settings.provider;
    final confirmed = await showSprichstConfirmation(
      context,
      title: 'Remove your ${provider.name} key?',
      message:
          'The key is deleted from this device. You can add it again later. To stop it working anywhere, delete it at ${provider.isCustom ? 'your provider' : provider.keyConsole}.',
      confirmLabel: 'Remove key',
      destructive: true,
    );
    if (!confirmed) return;
    await settings.removeKey();
    if (!mounted) return;
    _say('Key removed from this device.', ok: true);
  }

  Future<void> _useModel() async {
    final ok = await ref.read(cloudAISettingsProvider).setModel(_model.text);
    if (!mounted) return;
    if (ok) _model.clear();
    _say(
        ok
            ? 'Model saved.'
            : 'That is not a model id. Copy it from your provider, for example gpt-4.1-mini.',
        ok: ok);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(cloudAISettingsProvider);
    final provider = settings.provider;
    final hasKey = settings.hasKeyFor(provider);

    return SettingsSection(
      title: 'My own AI key',
      description:
          'Optional. Use an account you already have with Groq, Gemini, OpenAI, Claude, Grok, Mistral, DeepSeek, OpenRouter or any OpenAI-compatible server. '
          'Your messages go from this device straight to the provider you pick, and the key never leaves this device. You pay the provider, if anything, never Sprichst.',
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provider', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final p in cloudProviders)
                    ChoiceChip(
                      key: ValueKey('provider-${p.id}'),
                      label: Text(p.name),
                      selected: p.id == provider.id,
                      onSelected: (_) {
                        _key.clear();
                        setState(() => _result = null);
                        settings.setProvider(p.id);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (hasKey)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: context.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('Key saved: ${settings.maskedKey}',
                          key: const ValueKey('cloud-key-status')),
                    ),
                    TextButton(
                      key: const ValueKey('cloud-remove'),
                      onPressed: _remove,
                      child: const Text('Remove'),
                    ),
                  ],
                )
              else
                Text(
                  provider.isCustom
                      ? 'Enter the address of any server that speaks the OpenAI chat API (https only), and a key if it needs one.'
                      : '1. Sign in at ${provider.keyConsole}.\n'
                          '2. Create an API key.\n'
                          '3. Paste it below.'
                          '${provider.freeTier ? '\nThis provider has a free allowance.' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              if (provider.isCustom) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('cloud-url-field'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'https://…/v1',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('cloud-key-field'),
                controller: _key,
                obscureText: _hidden,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveAndTest(),
                decoration: InputDecoration(
                  labelText: hasKey
                      ? 'Replace key'
                      : provider.keyOptional
                          ? 'API key (if needed)'
                          : '${provider.name} API key',
                  hintText: provider.keyHint,
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
                key: const ValueKey('cloud-save'),
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
                    key: const ValueKey('cloud-result'),
                    style: TextStyle(
                        color: _resultOk
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Model', style: theme.textTheme.titleSmall),
              for (final model in provider.models)
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
              if (!provider.models.any((m) => m.id == settings.model) &&
                  settings.model.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('Using model: ${settings.model}',
                      key: const ValueKey('cloud-model-current')),
                ),
              TextField(
                key: const ValueKey('cloud-model-field'),
                controller: _model,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _useModel(),
                decoration: InputDecoration(
                  labelText: provider.models.isEmpty
                      ? 'Model id (required)'
                      : 'Or type another model id',
                  hintText:
                      'e.g. ${provider.models.isEmpty ? 'gpt-4.1-mini' : provider.models.last.id}',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('cloud-model-save'),
                  onPressed: _useModel,
                  child: const Text('Use this model'),
                ),
              ),
              if (!provider.canTranscribe)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '${provider.name} has no speech recognition here, so your recordings are transcribed on this phone.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
