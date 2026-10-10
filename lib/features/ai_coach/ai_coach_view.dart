import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../data/on_device/model_catalogue.dart';
import '../../data/on_device/on_device_ai_repository.dart';
import '../../domain/models/learning_models.dart';
import '../../domain/repositories/ai_exceptions.dart';
import '../../shared/input_rules.dart';
import '../../shared/widgets/app_widgets.dart';
import '../account/account_view.dart' show AIAndVoicePage;
import '../account/on_device_ai_page.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'voice/voice_mode_view.dart';
import 'voice/voice_session.dart';

class AICoachView extends ConsumerStatefulWidget {
  const AICoachView({super.key});

  @override
  ConsumerState<AICoachView> createState() => _AICoachViewState();
}

class _AICoachViewState extends ConsumerState<AICoachView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  var _shown = 0;

  final List<_Message> _messages = [];

  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final AudioPlayerService _audioPlayer = AudioPlayerService();

  var _sending = false;
  var _recording = false;
  var _transcribing = false;
  var _startingRecording = false;

  @override
  void initState() {
    super.initState();
    // An empty screen is a new conversation; the tutor must not remember an
    // earlier one the learner can no longer see.
    ref.read(appControllerProvider).startNewConversation();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    if (_messages.length != _shown) {
      _shown = _messages.length;
      _scrollToEnd();
    }

    return PageFrame(
      scrollsUnderNav: false,
      title: 'Practise talking',
      compactHeading: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Voice mode: talk hands-free',
            onPressed:
                _sending || _recording || _transcribing ? null : _openVoiceMode,
            icon: const Icon(Icons.graphic_eq),
          ),
          IconButton(
            tooltip: 'Coach settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const AIAndVoicePage())),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final t = context.tokens;
          final conversation = Column(
            children: [
              // The chip, the setup banner and the messages scroll together,
              // so a large text size or a short screen never pushes the
              // composer out of view.
              Expanded(
                child: ListView(
                  controller: _scroll,
                  children: [
                    const _ProviderChip(),
                    const SizedBox(height: AppSpacing.sm),
                    const _OfflineSetupBanner(),
                    if (_messages.isEmpty)
                      _CoachEmptyState(onVoiceMode: _openVoiceMode)
                    else
                      for (final message in _messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _MessageBubble(
                            message: message,
                            onSpeak: message.kind != _Kind.tutor
                                ? null
                                : () => _speakMessage(message),
                            onResendOnPhone: message.resendOnPhone == null ||
                                    _sending
                                ? null
                                : () =>
                                    _send(resendOnPhone: message.resendOnPhone),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.line))),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton.outlined(
                        tooltip:
                            _recording ? 'Stop recording' : 'Record German',
                        onPressed:
                            _sending || _transcribing ? null : _toggleRecording,
                        icon: _recording
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.mic_none),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 3,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                InputLimits.message),
                          ],
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Write in German…',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filledTonal(
                        tooltip: 'Send message',
                        onPressed: _sending || _recording || _transcribing
                            ? null
                            : _send,
                        icon: _sending || _transcribing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: t.ink,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          final contextCard = SoftCard(
            color: context.softSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Learning context',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  'Level: ${profile.currentLevel.label}',
                ),
                Text(
                  'Lesson: ${app.currentLesson?.title ?? 'Not started'}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Practice focus',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'German conversation, corrections, and vocabulary practice.',
                ),
              ],
            ),
          );

          if (constraints.maxWidth > Breakpoints.sideBySideContent) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: conversation,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: Breakpoints.sidePanelWidth,
                  child: contextCard,
                ),
              ],
            );
          }

          // Narrow screens keep the whole height for the conversation and show
          // the learning context as a single line instead of a card.
          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '${profile.currentLevel.label} · ${app.currentLesson?.title ?? 'Not started'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.tokens.inkMuted),
                  ),
                ),
              ),
              Expanded(child: conversation),
            ],
          );
        },
      ),
    );
  }

  /// Shows the newest message once the list has laid it out.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.standard(context),
        curve: AppMotion.curve,
      );
    });
  }

  /// Opens the hands-free conversation and keeps what was said in the chat.
  Future<void> _openVoiceMode() async {
    final turns = await Navigator.of(context).push<List<VoiceTurn>>(
      MaterialPageRoute(builder: (_) => const VoiceModeView()),
    );
    if (!mounted || turns == null || turns.isEmpty) return;
    setState(() {
      for (final turn in turns) {
        _messages
          ..add(_Message(text: turn.user, kind: _Kind.learner))
          ..add(_Message(
            text: turn.tutor,
            kind: _Kind.tutor,
            speechText: turn.speech,
          ));
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    // Ignore taps while the permission prompt or the recorder is starting.
    if (_startingRecording) return;
    _startingRecording = true;

    try {
      if (!await _audioRecorder.hasPermission()) {
        _showMessage(
          'Microphone access is off. Turn it on for Sprichst in your device '
          'settings to practise speaking.',
        );
        return;
      }

      await _audioRecorder.start();
      if (mounted) setState(() => _recording = true);
    } catch (error) {
      _showMessage('Could not start recording. Please try again.');
      debugPrint('Recording failed to start: $error');
    } finally {
      _startingRecording = false;
    }
  }

  /// Plain-language reason a voice turn failed; the raw error goes to the log.
  String _voiceErrorMessage(Object error) {
    if (error is ModelNotInstalledException ||
        error is ProviderUnavailableException ||
        error is VoiceUnavailableException) {
      return error.toString();
    }
    final text = error.toString();
    if (text.contains('No speech was detected')) {
      return 'I did not catch that. Hold the phone closer and try again.';
    }
    if (text.contains('No recording was created')) {
      return 'Nothing was recorded. Please try again.';
    }
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection')) {
      return 'Could not reach the AI service. Check your internet connection, or switch to "This phone only" in Account → AI & voice.';
    }
    return 'The voice conversation did not work this time. Please try again.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _stopRecording() async {
    try {
      setState(() {
        _recording = false;
        _transcribing = true;
      });

      final audio = await _audioRecorder.stop();

      if (audio == null) {
        throw Exception('No recording was created.');
      }

      final capture = AudioCapture(
        bytes: audio.bytes,
        filename: audio.filename,
        mimeType: audio.mimeType,
      );

      final app = ref.read(appControllerProvider);

      final result = await ref.read(aiRepositoryProvider).transcribeAudio(
            capture,
            app.tutorContext,
          );

      final text = result.text.trim();

      if (text.isEmpty) {
        throw Exception('No speech was detected.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _text.text = text;
        _text.selection = TextSelection.collapsed(
          offset: _text.text.length,
        );
        _transcribing = false;
      });

      await _send(
        speakResponse: true,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _transcribing = false;
        });

        _showMessage(_voiceErrorMessage(error));
        debugPrint('Voice conversation failed: $error');
      }
    }
  }

  /// Sends the typed message. [resendOnPhone] is the text of a message the
  /// cloud could not answer, sent again on this phone because the learner
  /// asked for that; its bubble is already on screen.
  Future<void> _send({
    bool speakResponse = false,
    String? resendOnPhone,
  }) async {
    final text = resendOnPhone ?? _text.text.trim();

    if (text.isEmpty || _sending || _recording || _transcribing) {
      return;
    }

    setState(() {
      if (resendOnPhone == null) {
        _messages.add(_Message(text: text, kind: _Kind.learner));
        _text.clear(); // the message is on screen now; leave the box empty
      }
      _sending = true;
    });

    try {
      final app = ref.read(appControllerProvider);
      final reply = resendOnPhone == null
          ? await app.chat(text)
          : await app.onThePhone(() => app.chat(text));

      final hasCorrection =
          reply.correction != null && reply.correction!.trim().isNotEmpty;
      // The tutor's words: the reply, then the question that goes on.
      final tutorMessage = [
        if (reply.reply.trim().isNotEmpty) reply.reply,
        if (reply.followUp.trim().isNotEmpty) reply.followUp,
      ].join('\n\n');

      final speechParts = <String>[
        if (reply.reply.trim().isNotEmpty) reply.reply,
        if (reply.correction != null && reply.correction!.trim().isNotEmpty)
          reply.correction!,
        if (reply.followUp.trim().isNotEmpty) reply.followUp,
      ];

      final speechText = speechParts.join(' ').trim();

      if (!mounted) {
        return;
      }

      setState(() {
        // A correction is only shown when the provider returned one, with the
        // fields it returned.
        if (hasCorrection) {
          _messages.add(_Message(
            kind: _Kind.correction,
            text: text,
            corrected: reply.correction!.trim(),
            explanation: reply.explanation?.trim(),
          ));
        }
        if (tutorMessage.isNotEmpty) {
          _messages.add(_Message(
            text: tutorMessage,
            speechText: speechText,
            kind: _Kind.tutor,
          ));
        }
      });

      if (speakResponse && speechText.isNotEmpty) {
        final audio = await app.speak(speechText);

        await _audioPlayer.playBytes(audio.bytes);
      }
    } catch (error) {
      if (mounted) {
        // These carry their own plain-language explanation of what to do.
        final explained = error is ModelNotInstalledException ||
            error is ProviderUnavailableException ||
            error is VoiceUnavailableException;
        // Offer the phone, never do it unasked: the learner decides where
        // their words go.
        final phoneReady = error is ProviderUnavailableException &&
            error.canOfferPhone &&
            ref.read(modelManagerProvider).activeTutor != null;
        setState(() {
          _messages.add(
            _Message(
              text: explained
                  ? error.toString()
                  : 'Couldn’t reach the coach. Lessons and reviews still work offline.',
              kind: _Kind.notice,
              resendOnPhone: phoneReady ? text : null,
            ),
          );
        });

        if (!explained) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Coach error: $error'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _speakMessage(_Message message) async {
    final speechText = message.speechText;

    if (speechText == null || speechText.trim().isEmpty) {
      return;
    }

    try {
      final app = ref.read(appControllerProvider);

      final audio = await app.speak(speechText);

      await _audioPlayer.playBytes(audio.bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech playback failed: $error'),
          ),
        );
      }
    }
  }
}

/// Says where the learner's words go, as the provider labels do: "This phone
/// only · nothing leaves your phone" or "Groq (my own key) · sends your messages
/// to Groq".
class _ProviderChip extends ConsumerWidget {
  const _ProviderChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    final models = ref.watch(modelManagerProvider);
    final hasKey = ref.watch(groqSettingsProvider).hasKey;
    final onPhone = models.isSupported && models.activeTutor != null;

    final (label, icon) = switch (profile.aiProviderPreference) {
      AIProviderPreference.local => (
          '${profile.aiProviderPreference.label} · nothing leaves your phone',
          Icons.phone_android
        ),
      AIProviderPreference.groq => (
          '${profile.aiProviderPreference.label} · sends your messages to Groq',
          Icons.cloud_outlined
        ),
      AIProviderPreference.automatic => onPhone
          ? ('Automatic · answers on this phone', Icons.phone_android)
          : hasKey
              ? (
                  'Automatic · sends your messages to Groq until a model is downloaded',
                  Icons.cloud_outlined
                )
              : (
                  'Automatic · download a model or add a Groq key to start',
                  Icons.info_outline
                ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DsChip(label, icon: icon),
    );
  }
}

/// Shown until a tutor model is on the phone: the coach then works offline.
class _OfflineSetupBanner extends ConsumerWidget {
  const _OfflineSetupBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelManagerProvider);
    models.ensureLoaded();
    if (!models.isSupported || !models.isReady || models.activeTutor != null) {
      return const SizedBox.shrink();
    }
    final tutor = models.recommendedTutorModel;
    final downloading = models.progressOf(tutor.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: downloading != null
          ? SoftCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Downloading ${tutor.label}…'),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(value: downloading),
                ],
              ),
            )
          : FeedbackBanner(
              tone: BannerTone.info,
              title: 'Use the coach without internet',
              message:
                  'Download ${tutor.label} (${formatBytes(tutor.downloadBytes)}), recommended for this phone.',
              actionLabel: 'Set up',
              onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const OnDeviceAIPage())),
            ),
    );
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({required this.onVoiceMode});

  final VoidCallback onVoiceMode;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: StateMessage(
            kind: StateKind.empty,
            title: 'Start a German conversation',
            message:
                'Write a sentence, or just talk. Voice mode listens, answers aloud and listens again.',
            actionLabel: 'Start voice conversation',
            onAction: onVoiceMode,
          ),
        ),
      );
}

enum _Kind { learner, tutor, correction, notice }

class _Message {
  const _Message({
    required this.text,
    required this.kind,
    this.speechText,
    this.resendOnPhone,
    this.corrected,
    this.explanation,
  });

  /// What was said. For a correction, the learner's original sentence.
  final String text;
  final _Kind kind;
  final String? speechText;

  /// The learner's message, when the cloud could not answer it and this phone
  /// can: shown with an "Answer on this phone" button.
  final String? resendOnPhone;

  /// A correction's corrected sentence and why (only what the provider sent).
  final String? corrected;
  final String? explanation;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSpeak,
    this.onResendOnPhone,
  });

  final _Message message;
  final VoidCallback? onSpeak;
  final VoidCallback? onResendOnPhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    switch (message.kind) {
      case _Kind.notice:
        return FeedbackBanner(
          tone: message.resendOnPhone != null
              ? BannerTone.warning
              : BannerTone.offline,
          title: 'The coach could not answer',
          message: message.text,
          actionLabel:
              message.resendOnPhone != null ? 'Answer on this phone' : null,
          onAction: onResendOnPhone,
        );
      case _Kind.correction:
        return _CorrectionCard(message: message);
      case _Kind.learner:
      case _Kind.tutor:
        final mine = message.kind == _Kind.learner;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Breakpoints.messageMaxWidth),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: mine ? t.panel : t.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: mine ? BorderSide.none : BorderSide(color: t.line),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      locale: const Locale('de'),
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: mine ? t.onPanel : t.ink),
                    ),
                    if (onSpeak != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      IconButton(
                        tooltip: 'Listen',
                        onPressed: onSpeak,
                        icon: const Icon(Icons.volume_up_outlined),
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
}

/// What the learner wrote, the corrected sentence, and why. The original
/// carries a wavy underline as well as its "You wrote" label.
class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: Breakpoints.messageMaxWidth),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.edit_note, color: t.ink, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text('CORRECTION', style: theme.textTheme.labelSmall),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Text('You wrote',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: t.inkMuted)),
              Text(
                message.text,
                locale: const Locale('de'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.wavy,
                  decorationColor: t.danger,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Better',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: t.inkMuted)),
              Text(message.corrected ?? '',
                  locale: const Locale('de'),
                  style: theme.textTheme.headlineSmall),
              if (message.explanation != null &&
                  message.explanation!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message.explanation!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
