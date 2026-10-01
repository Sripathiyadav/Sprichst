import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class AICoachView extends ConsumerStatefulWidget {
  const AICoachView({super.key});

  @override
  ConsumerState<AICoachView> createState() => _AICoachViewState();
}

class _AICoachViewState extends ConsumerState<AICoachView> {
  final _text = TextEditingController(text: 'Ich gehen morgen zur Arbeit.');
  final List<_Message> _messages = [];
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    return PageFrame(
      title: 'AI Coach',
      subtitle:
          'A German tutor that uses your level and current learning path.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final conversation = Column(children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _CoachEmptyState()
                  : ListView.separated(
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _MessageBubble(message: _messages[index]),
                    ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send())),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send)),
            ]),
          ]);
          final contextCard = SoftCard(
            color: SprichstTheme.sand,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('LEARNING CONTEXT',
                      style: TextStyle(
                          color: SprichstTheme.forest,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 14),
                  Text('Level: ${profile.currentLevel.label}'),
                  Text('Lesson: ${app.currentLesson!.title}'),
                  const SizedBox(height: 12),
                  const Text('Weak areas',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Articles · verb conjugation'),
                  const SizedBox(height: 12),
                  const Text(
                      'Demo mode uses a deterministic local fallback. Start ai-server to connect Ollama.',
                      style: TextStyle(fontSize: 12)),
                ]),
          );
          if (constraints.maxWidth > 820) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: conversation),
              const SizedBox(width: 20),
              SizedBox(width: 260, child: contextCard)
            ]);
          }
          return Column(children: [
            Expanded(child: conversation),
            const SizedBox(height: 16),
            contextCard
          ]);
        },
      ),
    );
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Message(text: text, fromUser: true));
      _sending = true;
    });
    try {
      final reply = await ref.read(appControllerProvider).correctGerman(text);
      if (mounted) {
        setState(() => _messages.add(_Message(
            text:
                '${reply.wasCorrect ? 'Looks good.' : 'Almost correct.'}\n\n${reply.corrected}\n\n${reply.explanation}\n\n${reply.followUp}',
            fromUser: false)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(const _Message(
            text: 'I could not reach the coach. Please try again.',
            fromUser: false)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState();
  @override
  Widget build(BuildContext context) => Center(
          child: SoftCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.forum_outlined, size: 44, color: SprichstTheme.forest),
        const SizedBox(height: 12),
        Text('Try a sentence in German',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
            'Ask for a correction, grammar explanation, or vocabulary help.',
            textAlign: TextAlign.center)
      ])));
}

class _Message {
  const _Message({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _Message message;
  @override
  Widget build(BuildContext context) => Align(
        alignment:
            message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: message.fromUser ? SprichstTheme.forest : Colors.white,
                borderRadius: BorderRadius.circular(18)),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(message.text,
                    style: TextStyle(
                        color:
                            message.fromUser ? Colors.white : SprichstTheme.ink,
                        height: 1.45))),
          ),
        ),
      );
}
