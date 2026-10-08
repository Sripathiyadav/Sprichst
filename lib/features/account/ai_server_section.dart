import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/ai/ai_server_settings.dart';
import '../../shared/widgets/app_widgets.dart';

/// Where the app finds the AI server, with a connection test.
///
/// On a simulator the default works. On a real phone the learner enters their
/// computer's address here, because "127.0.0.1" would mean the phone itself.
class AiServerSection extends ConsumerStatefulWidget {
  const AiServerSection({super.key});

  @override
  ConsumerState<AiServerSection> createState() => _AiServerSectionState();
}

class _AiServerSectionState extends ConsumerState<AiServerSection> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(aiServerSettingsProvider).url,
  );
  ConnectionReport? _report;
  var _testing = false;
  String? _invalid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final settings = ref.read(aiServerSettingsProvider);
    setState(() {
      _testing = true;
      _invalid = null;
      _report = null;
    });
    final saved = await settings.save(_controller.text);
    if (!saved) {
      if (mounted) {
        setState(() {
          _testing = false;
          _invalid =
              'That does not look like an address. Try something like 192.168.1.20 or http://192.168.1.20:8000.';
        });
      }
      return;
    }
    _controller.text = settings.url;
    final report = await checkAiServer(settings.url);
    if (mounted) {
      setState(() {
        _testing = false;
        _report = report;
      });
    }
  }

  Future<void> _useDefault() async {
    final settings = ref.read(aiServerSettingsProvider);
    await settings.save('');
    _controller.text = settings.url;
    if (mounted) setState(() => _report = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiServerSettingsProvider);
    final report = _report;
    return SettingsSection(
      title: 'AI server',
      description:
          'The optional server that powers the tutor, voices and speech recognition. '
          'On a simulator the default works. On a real phone, enter your computer\'s '
          'address (for example 192.168.1.20) and start the server with ai-server/run.sh.',
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('ai-server-address'),
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _saveAndTest(),
                decoration: InputDecoration(
                  labelText: 'Server address',
                  hintText: settings.defaultUrl,
                  errorText: _invalid,
                  helperText: settings.isCustom
                      ? 'Custom address. Default: ${settings.defaultUrl}'
                      : 'Using the default address for this device.',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.icon(
                    onPressed: _testing ? null : _saveAndTest,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Save and test'),
                  ),
                  if (settings.isCustom)
                    TextButton(
                      onPressed: _testing ? null : _useDefault,
                      child: const Text('Use default'),
                    ),
                ],
              ),
              if (report != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        report.isOk ? Icons.check_circle : Icons.error_outline,
                        color: report.isOk
                            ? context.accent
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.detail,
                                style: theme.textTheme.titleSmall),
                            if (report.hint != null)
                              Text(report.hint!,
                                  style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
