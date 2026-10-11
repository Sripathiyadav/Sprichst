import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/on_device/model_catalogue.dart';
import '../../data/on_device/on_device_ai_repository.dart';
import '../../domain/models/learning_models.dart';
import '../ai_coach/services/audio_player_service.dart';

/// Lets the learner choose the tutor's voice and hear each one first.
///
/// The open-source (Piper) voices are downloaded to the phone and run there,
/// offline. A voice that is not downloaded yet can be downloaded in place;
/// until it is, the tutor speaks with the best voice it has.
class VoicePicker extends ConsumerStatefulWidget {
  const VoicePicker(
      {super.key, required this.selectedId, required this.onChanged});

  final String selectedId;
  final ValueChanged<String> onChanged;

  static const previewText =
      'Hallo! Ich bin dein Deutschlehrer. Wollen wir zusammen üben?';

  @override
  ConsumerState<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends ConsumerState<VoicePicker> {
  final _player = AudioPlayerService();
  late Future<VoiceList> _voices = ref.read(appControllerProvider).loadVoices();
  String? _previewing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(VoiceOption voice) async {
    if (_previewing != null) return;
    setState(() => _previewing = voice.id);
    try {
      final audio = await ref
          .read(appControllerProvider)
          .speak(VoicePicker.previewText, voice: voice.id);
      if (audio.usedFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${voice.label} is not downloaded yet, so you heard another voice.'),
        ));
      }
      await _player.playBytes(audio.bytes);
    } on ModelNotInstalledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download ${voice.label} to hear it.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not play the preview.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<VoiceList>(
        future: _voices,
        builder: (context, snapshot) {
          final list = snapshot.data;
          if (list == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final selected = list.find(widget.selectedId)?.id ?? list.defaultId;
          final open = [
            for (final v in list.voices)
              if (v.isOpenSource) v
          ];
          final system = [
            for (final v in list.voices)
              if (!v.isOpenSource) v
          ];
          return RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) widget.onChanged(value);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Heading('German voices (open-source Piper, run on this phone)',
                    onRefresh: () => setState(() {
                          _voices =
                              ref.read(appControllerProvider).loadVoices();
                        })),
                for (final voice in open)
                  _VoiceTile(
                    voice: voice,
                    previewing: _previewing == voice.id,
                    onPreview: () => _preview(voice),
                  ),
                if (system.isNotEmpty) ...[
                  const _Heading('System voices'),
                  for (final voice in system)
                    _VoiceTile(
                      voice: voice,
                      previewing: _previewing == voice.id,
                      onPreview: () => _preview(voice),
                    ),
                ],
              ],
            ),
          );
        },
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.onRefresh});

  final String text;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
        child: Row(children: [
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.labelLarge)),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Check which voices are downloaded',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ]),
      );
}

class _VoiceTile extends ConsumerWidget {
  const _VoiceTile({
    required this.voice,
    required this.previewing,
    required this.onPreview,
  });

  final VoiceOption voice;
  final bool previewing;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final models = ref.watch(modelManagerProvider);
    final download = models.isSupported ? voiceModels[voice.id] : null;
    final onPhone = download != null && models.isInstalled(voice.id);
    final progress = download == null ? null : models.progressOf(voice.id);
    final error = download == null ? null : models.errors[voice.id];
    final status = download != null
        ? (onPhone
            ? 'On this phone'
            : 'Not downloaded · ${formatBytes(download.downloadBytes)}')
        : switch (voice.available) {
            true => 'Installed',
            false => 'Not installed',
            null => 'Install status unknown',
          };
    final details = [
      if (voice.quality.isNotEmpty) '${voice.quality} quality',
      voice.license,
      status,
    ].where((e) => e.isNotEmpty).join(' · ');
    return RadioListTile<String>(
      value: voice.id,
      contentPadding:
          const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      title: Text(voice.label, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(voice.description),
          const SizedBox(height: 2),
          Text(details, style: theme.textTheme.bodySmall),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(value: progress),
            ),
          if (error != null)
            Text(error,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          if (download == null &&
              voice.available == false &&
              voice.installHint != null)
            Text('Install: ${voice.installHint}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
        ],
      ),
      secondary: download != null && !onPhone
          ? (models.isDownloading(voice.id)
              ? IconButton(
                  tooltip: 'Pause download',
                  onPressed: () => models.cancel(voice.id),
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                )
              : IconButton(
                  tooltip: 'Download ${voice.label}',
                  onPressed: () => models.download(voice.id),
                  icon: const Icon(Icons.download_rounded),
                ))
          : previewing
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton(
                  tooltip: 'Preview ${voice.label}',
                  onPressed: onPreview,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
    );
  }
}
