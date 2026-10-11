import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../data/on_device/model_catalogue.dart';
import '../../data/on_device/model_manager.dart';
import '../../shared/widgets/app_widgets.dart';

/// Download and choose the models that run the AI Coach on this phone.
class OnDeviceAIPage extends ConsumerStatefulWidget {
  const OnDeviceAIPage({super.key});

  @override
  ConsumerState<OnDeviceAIPage> createState() => _OnDeviceAIPageState();
}

class _OnDeviceAIPageState extends ConsumerState<OnDeviceAIPage> {
  @override
  void initState() {
    super.initState();
    ref.read(modelManagerProvider).ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelManagerProvider);
    if (!models.isSupported) {
      return const SettingsPage(
        title: 'On-device AI',
        subtitle:
            'Models cannot run inside a browser. Install the app on your phone to use the coach offline.',
        children: [],
      );
    }
    if (!models.isReady) {
      return const SettingsPage(
        title: 'On-device AI',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final ram = models.ramMb;
    return SettingsPage(
      title: 'On-device AI',
      subtitle:
          'Download the coach once and it works anywhere, with no internet. Nothing you say or write leaves your phone.',
      children: [
        SoftCard(
          color: context.softSurface,
          child: Text(
            [
              ram == null
                  ? 'We could not read how much memory this phone has.'
                  : 'This phone has ${(ram / 1024).toStringAsFixed(ram < 4096 ? 1 : 0)} GB of memory.',
              'We recommend ${models.recommendedTutorModel.label} for the tutor and ${models.recommendedSpeechModel.label} for speech.',
              if (models.isSimulator)
                'Simulator: models run on the CPU here, so answers are slower than on a real phone.',
              'Downloads are large: use Wi-Fi.',
            ].join(' '),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ModelSection(
          title: 'Tutor',
          description:
              'Answers your messages and corrects your German. Bigger models explain better but need more memory and storage.',
          options: tutorModels,
          recommended: models.recommendedTutorModel,
          selected: models.selectedTutor,
          onSelect: models.selectTutor,
        ),
        _ModelSection(
          title: 'Speech recognition',
          description: 'Understands what you say in voice practice.',
          options: speechRecognitionModels,
          recommended: models.recommendedSpeechModel,
          selected: models.selectedSpeechModel,
          onSelect: models.selectSpeechModel,
        ),
        const SettingsSection(
          title: 'Voices',
          description:
              'Choose and download the tutor\'s voice in AI & voice → Voice. Each voice is about 25–115 MB.',
          children: [],
        ),
      ],
    );
  }
}

class _ModelSection extends ConsumerWidget {
  const _ModelSection({
    required this.title,
    required this.description,
    required this.options,
    required this.recommended,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String description;
  final List<OnDeviceModel> options;
  final OnDeviceModel recommended;
  final OnDeviceModel selected;
  final Future<void> Function(String id) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelManagerProvider);
    return SettingsSection(
      title: title,
      description: description,
      children: [
        RadioGroup<String>(
          groupValue: selected.id,
          onChanged: (id) {
            if (id != null) onSelect(id);
          },
          child: Column(children: [
            for (final model in options)
              ModelTile(
                model: model,
                fit: fitFor(model, models.ramMb, recommended),
                selectable: true,
              ),
          ]),
        ),
      ],
    );
  }
}

/// One downloadable model: what it is, how it fits this phone, and a
/// download / progress / delete control.
class ModelTile extends ConsumerWidget {
  const ModelTile({
    super.key,
    required this.model,
    required this.fit,
    this.selectable = false,
  });

  final OnDeviceModel model;
  final ModelFit fit;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelManagerProvider);
    final theme = Theme.of(context);
    final installed = models.isInstalled(model.id);
    final progress = models.progressOf(model.id);
    final error = models.errors[model.id];
    final details = [
      formatBytes(model.downloadBytes),
      model.license,
      installed ? 'On this phone' : 'Not downloaded',
    ].join(' · ');
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fit != ModelFit.fits)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              fit == ModelFit.recommended
                  ? 'Best for this phone'
                  : 'May be too large for this phone\'s memory',
              style: theme.textTheme.labelMedium?.copyWith(
                color: fit == ModelFit.recommended
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        Text(model.description),
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
      ],
    );
    final action = _ModelAction(model: model, models: models);
    if (!selectable) {
      return ListTile(
        contentPadding:
            const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
        title: Text(model.label, style: theme.textTheme.titleMedium),
        subtitle: subtitle,
        trailing: action,
      );
    }
    return RadioListTile<String>(
      value: model.id,
      contentPadding:
          const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      title: Text(model.label, style: theme.textTheme.titleMedium),
      subtitle: subtitle,
      secondary: action,
    );
  }
}

class _ModelAction extends StatelessWidget {
  const _ModelAction({required this.model, required this.models});

  final OnDeviceModel model;
  final ModelManager models;

  @override
  Widget build(BuildContext context) {
    if (models.isDownloading(model.id)) {
      return IconButton(
        tooltip: 'Pause download',
        onPressed: () => models.cancel(model.id),
        icon: const Icon(Icons.pause_circle_outline_rounded),
      );
    }
    if (models.isInstalled(model.id)) {
      return IconButton(
        tooltip: 'Delete ${model.label}',
        onPressed: () => _confirmDelete(context),
        icon: const Icon(Icons.delete_outline_rounded),
      );
    }
    return IconButton(
      tooltip: 'Download ${model.label}',
      onPressed: () => models.download(model.id),
      icon: const Icon(Icons.download_rounded),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showSprichstConfirmation(
      context,
      title: 'Delete ${model.label}?',
      message:
          'This frees ${formatBytes(model.downloadBytes)}. You will need internet to download it again.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await models.delete(model.id);
  }
}
