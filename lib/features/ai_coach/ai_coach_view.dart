import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../data/on_device/model_catalogue.dart';
import '../../data/on_device/on_device_ai_repository.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/input_rules.dart';
import '../../shared/widgets/app_widgets.dart';
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;

    return PageFrame(
      scrollsUnderNav: false,
      title: 'AI Coach',
      subtitle:
          'Practice German with your personal tutor through text or voice.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final conversation = Column(
            children: [
              const _OfflineSetupBanner(),
              Expanded(
                child: _messages.isEmpty
                    ? _CoachEmptyState(onVoiceMode: _openVoiceMode)
                    : ListView.separated(
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final message = _messages[index];

                          return _MessageBubble(
                            message: message,
                            onSpeak: message.fromUser
                                ? null
                                : () => _speakMessage(message),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 3,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(InputLimits.message),
                      ],
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Write something in German...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Voice mode: talk hands-free',
                    onPressed: _sending || _recording || _transcribing
                        ? null
                        : _openVoiceMode,
                    icon: const Icon(Icons.graphic_eq),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: _recording ? 'Stop recording' : 'Record German',
                    onPressed:
                        _sending || _transcribing ? null : _toggleRecording,
                    icon: _recording
                        ? const Icon(Icons.stop)
                        : const Icon(Icons.mic),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed:
                        _sending || _recording || _transcribing ? null : _send,
                    icon: _sending || _transcribing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
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
                    style: Theme.of(context).textTheme.bodyMedium,
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

  /// Opens the hands-free conversation and keeps what was said in the chat.
  Future<void> _openVoiceMode() async {
    final turns = await Navigator.of(context).push<List<VoiceTurn>>(
      MaterialPageRoute(builder: (_) => const VoiceModeView()),
    );
    if (!mounted || turns == null || turns.isEmpty) return;
    setState(() {
      for (final turn in turns) {
        _messages
          ..add(_Message(text: turn.user, fromUser: true))
          ..add(_Message(
            text: turn.tutor,
            fromUser: false,
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
    if (error is ModelNotInstalledException) return error.toString();
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
      return 'Could not reach the AI server. Check that it is running and that the address is right in Account → AI & voice → AI server.';
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

  Future<void> _send({
    bool speakResponse = false,
  }) async {
    final text = _text.text.trim();

    if (text.isEmpty || _sending || _recording || _transcribing) {
      return;
    }

    setState(() {
      _messages.add(
        _Message(
          text: text,
          fromUser: true,
        ),
      );
      _sending = true;
      _text.clear(); // the message is on screen now; leave the box empty
    });

    try {
      final app = ref.read(appControllerProvider);
      final reply = await app.chat(text);

      final displayParts = <String>[
        if (reply.reply.trim().isNotEmpty) reply.reply,
        if (reply.correction != null && reply.correction!.trim().isNotEmpty)
          'Correction: ${reply.correction}',
        if (reply.explanation != null && reply.explanation!.trim().isNotEmpty)
          reply.explanation!,
        if (reply.followUp.trim().isNotEmpty) reply.followUp,
      ];

      final tutorMessage = displayParts.join('\n\n');

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
        _messages.add(
          _Message(
            text: tutorMessage,
            speechText: speechText,
            fromUser: false,
          ),
        );
      });

      if (speakResponse && speechText.isNotEmpty) {
        final audio = await app.speak(speechText);

        await _audioPlayer.playBytes(audio.bytes);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages.add(
            _Message(
              text: error is ModelNotInstalledException
                  ? error.toString()
                  : 'I could not reach the coach. Check Account → AI & voice → AI server, then try again.',
              fromUser: false,
            ),
          );
        });

        if (error is! ModelNotInstalledException) {
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
      child: SoftCard(
        color: context.softSurface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          const Icon(Icons.offline_bolt_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: downloading != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloading ${tutor.label}…'),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(value: downloading),
                    ],
                  )
                : Text(
                    'Use the coach without internet: download ${tutor.label} (${formatBytes(tutor.downloadBytes)}), recommended for this phone.'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const OnDeviceAIPage())),
            child: const Text('Set up'),
          ),
        ]),
      ),
    );
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({required this.onVoiceMode});

  final VoidCallback onVoiceMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Start a German conversation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Write a sentence, or just talk: voice mode listens, answers aloud and listens again, with no buttons in between.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onVoiceMode,
                icon: const Icon(Icons.graphic_eq),
                label: const Text('Start voice conversation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message {
  const _Message({
    required this.text,
    required this.fromUser,
    this.speechText,
  });

  final String text;
  final bool fromUser;
  final String? speechText;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSpeak,
  });

  final _Message message;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: Breakpoints.messageMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: message.fromUser
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: message.fromUser
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.fromUser
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.45,
                  ),
                ),
                if (onSpeak != null) ...[
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: 'Listen',
                    onPressed: onSpeak,
                    icon: const Icon(
                      Icons.volume_up_outlined,
                    ),
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
