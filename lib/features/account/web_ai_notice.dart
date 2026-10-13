import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'account_view.dart';

/// In a web browser there are no on-device models, so the coach, the
/// translator and speech recognition need the learner's own AI key. This says
/// so, with a way to add one, until a key is saved. Everywhere else, and once a
/// key is there, it takes no room.
class WebAiNotice extends ConsumerWidget {
  const WebAiNotice({super.key, this.margin = AppSpacing.md});

  /// Space left below the notice when it is shown.
  final double margin;

  static const title = 'No local model in the browser';
  static const message =
      'Local AI models run in the phone and desktop apps, not in a web browser, so nothing works offline here. '
      'To use the coach, the translator and speech recognition, add your own AI key (Groq and Gemini have free plans).';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelManagerProvider);
    final hasKey = ref.watch(cloudAISettingsProvider).isConfigured;
    if (models.isSupported || hasKey) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: margin),
      child: FeedbackBanner(
        key: const ValueKey('web-ai-notice'),
        tone: BannerTone.info,
        title: title,
        message: message,
        actionLabel: 'Add my AI key',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AIAndVoicePage()),
        ),
      ),
    );
  }
}
