import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../data/on_device/on_device_ai_repository.dart'
    show ModelNotInstalledException;
import '../../domain/models/learning_models.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../shared/input_rules.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/speak_button.dart';
import '../account/web_ai_notice.dart';

/// Opens the translator.
void openTranslator(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const TranslatorView()),
  );
}

/// German and English, any text typed or pasted. It uses the same AI as the
/// coach: this phone, or the learner's own AI key. Nothing is sent to Sprichst.
class TranslatorView extends ConsumerStatefulWidget {
  const TranslatorView({super.key});

  @override
  ConsumerState<TranslatorView> createState() => _TranslatorViewState();
}

class _TranslatorViewState extends ConsumerState<TranslatorView> {
  final _input = TextEditingController();
  var _direction = TranslationDirection.germanToEnglish;
  var _busy = false;
  String? _result;

  /// The direction and text the shown [_result] belongs to.
  TranslationDirection? _resultDirection;
  String? _error;
  var _canUsePhone = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _hasText => _input.text.trim().isNotEmpty;

  void _swap() {
    setState(() {
      // What was translated becomes the text to translate back.
      final shown = _result;
      _direction = _direction.swapped;
      if (shown != null) {
        _input.text = shown;
        _result = null;
        _resultDirection = null;
      }
      _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() {
      _input.text = sanitizeText(text, maxLength: InputLimits.translation);
      _result = null;
      _error = null;
    });
  }

  void _clear() => setState(() {
        _input.clear();
        _result = null;
        _resultDirection = null;
        _error = null;
      });

  Future<void> _translate({bool onPhone = false}) async {
    if (_busy || !_hasText) return;
    final app = ref.read(appControllerProvider);
    final direction = _direction;
    setState(() {
      _busy = true;
      _error = null;
      _canUsePhone = false;
    });
    try {
      final text = onPhone
          ? await app.onThePhone(() => app.translate(_input.text, direction))
          : await app.translate(_input.text, direction);
      if (!mounted) return;
      setState(() {
        _result = text;
        _resultDirection = direction;
      });
    } catch (error) {
      if (!mounted) return;
      final explained = error is ModelNotInstalledException ||
          error is ProviderUnavailableException ||
          error is HearingUnavailableException ||
          error is LocalModelsUnavailableException;
      setState(() {
        _result = null;
        _error = explained
            ? error.toString()
            : error is ArgumentError
                ? 'Write or paste a text first.'
                : 'The translation did not work. Please try again.';
        // Offer the phone, never do it unasked: the learner decides where
        // their text goes.
        _canUsePhone = error is ProviderUnavailableException &&
            error.canOfferPhone &&
            ref.read(modelManagerProvider).activeTutor != null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final text = _result;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Translation copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final d = _direction;
    return GlassPage(
      appBar: const MastheadBar(eyebrow: 'Translator'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.lessonMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Semantics(
                  header: true,
                  child: Text('German and English',
                      style: theme.textTheme.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Type or paste any text. It is translated on this phone, or with the AI key you added. Sprichst never sees it.',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                const WebAiNotice(),
                _DirectionBar(direction: d, onSwap: _swap),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('translate-input'),
                  controller: _input,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: InputLimits.translation,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  autocorrect: false,
                  onChanged: (_) => setState(() {
                    _result = null;
                    _error = null;
                  }),
                  decoration: InputDecoration(
                    labelText: '${d.sourceName} text',
                    alignLabelWithHint: true,
                    hintText: d == TranslationDirection.germanToEnglish
                        ? 'Schreibe oder füge einen Text ein…'
                        : 'Write or paste a text…',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('translate-paste'),
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste'),
                    ),
                    if (_hasText)
                      OutlinedButton.icon(
                        key: const ValueKey('translate-clear'),
                        onPressed: _clear,
                        icon: const Icon(Icons.close),
                        label: const Text('Clear'),
                      ),
                    if (_hasText && d == TranslationDirection.germanToEnglish)
                      SpeakButton(
                          text: _input.text, label: 'Listen', filled: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  key: const ValueKey('translate-go'),
                  label:
                      _busy ? 'Translating…' : 'Translate to ${d.targetName}',
                  block: true,
                  onPressed: _busy || !_hasText ? null : _translate,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FeedbackBanner(
                    tone: _canUsePhone ? BannerTone.warning : BannerTone.danger,
                    title: 'Could not translate',
                    message: _error!,
                    actionLabel:
                        _canUsePhone ? 'Translate on this phone' : null,
                    onAction:
                        _canUsePhone ? () => _translate(onPhone: true) : null,
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ResultCard(
                    text: _result!,
                    direction: _resultDirection ?? d,
                    onCopy: _copy,
                    onSwap: _swap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "German ⇄ English" as two labels and a swap button.
class _DirectionBar extends StatelessWidget {
  const _DirectionBar({required this.direction, required this.onSwap});

  final TranslationDirection direction;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    Widget side(String label, String caption) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: t.lineStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption.toUpperCase(),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: t.inkMuted)),
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        );
    return Semantics(
      container: true,
      label:
          'Translating from ${direction.sourceName} to ${direction.targetName}',
      child: Row(
        children: [
          side(direction.sourceName, 'From'),
          IconButton(
            key: const ValueKey('translate-swap'),
            tooltip: 'Swap languages',
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz),
          ),
          side(direction.targetName, 'To'),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.text,
    required this.direction,
    required this.onCopy,
    required this.onSwap,
  });

  final String text;
  final TranslationDirection direction;
  final VoidCallback onCopy;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final german = direction.targetCode == 'de';
    return SoftCard(
      key: const ValueKey('translate-result'),
      color: t.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(direction.targetName.toUpperCase(),
              style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            text,
            key: const ValueKey('translate-output'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('translate-copy'),
                onPressed: onCopy,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              if (german)
                SpeakButton(text: text, label: 'Listen', filled: true),
              OutlinedButton.icon(
                key: const ValueKey('translate-back'),
                onPressed: onSwap,
                icon: const Icon(Icons.swap_horiz),
                label: Text('Translate back to ${direction.sourceName}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
