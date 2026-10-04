import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';

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
      title: 'AI Coach',
      subtitle:
          'Practice German with your personal tutor through text or voice.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final conversation = Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const _CoachEmptyState()
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
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Write something in German...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _recording ? 'Stop recording' : 'Record German',
                    onPressed:
                        _sending || _transcribing ? null : _toggleRecording,
                    icon: _recording
                        ? const Icon(Icons.stop)
                        : const Icon(Icons.mic),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed:
                        _sending || _recording || _transcribing ? null : _send,
                    child: _sending || _transcribing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          );

          final contextCard = SoftCard(
            color: SprichstTheme.sand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LEARNING CONTEXT',
                  style: TextStyle(
                    color: SprichstTheme.forest,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
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

          if (constraints.maxWidth > 820) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: conversation,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 260,
                  child: contextCard,
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: conversation,
              ),
              const SizedBox(height: 16),
              contextCard,
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }

    try {
      final permission = await _audioRecorder.hasPermission();

      if (!permission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required.'),
            ),
          );
        }
        return;
      }

      await _audioRecorder.start();

      if (mounted) {
        setState(() {
          _recording = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $error'),
          ),
        );
      }
    }
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
            app.profile!,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice conversation failed: $error'),
          ),
        );
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
    });

    try {
      final app = ref.read(appControllerProvider);
      final reply = await app.chat(text);

      final displayParts = <String>[
        reply.reply,
        if (reply.correction != null && reply.correction!.trim().isNotEmpty)
          'Correction: ${reply.correction}',
        if (reply.explanation != null && reply.explanation!.trim().isNotEmpty)
          reply.explanation!,
        if (reply.followUp.trim().isNotEmpty) reply.followUp,
      ];

      final tutorMessage = displayParts.join('\n\n');

      final speechParts = <String>[
        reply.reply,
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
        final audio = await ref.read(aiRepositoryProvider).synthesizeSpeech(
              speechText,
              app.profile!,
            );

        await _audioPlayer.playBytes(audio);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages.add(
            const _Message(
              text: 'I could not reach the coach. Please try again.',
              fromUser: false,
            ),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Coach error: $error'),
          ),
        );
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

      final audio = await ref.read(aiRepositoryProvider).synthesizeSpeech(
            speechText,
            app.profile!,
          );

      await _audioPlayer.playBytes(audio);
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

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SoftCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 44,
              color: SprichstTheme.forest,
            ),
            const SizedBox(height: 12),
            Text(
              'Start a German conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Write a sentence or use the microphone to talk with your tutor.',
              textAlign: TextAlign.center,
            ),
          ],
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
        constraints: const BoxConstraints(
          maxWidth: 560,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: message.fromUser ? SprichstTheme.forest : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.fromUser ? Colors.white : SprichstTheme.ink,
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
