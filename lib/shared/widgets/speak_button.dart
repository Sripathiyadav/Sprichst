import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../features/ai_coach/services/audio_player_service.dart';

/// Plays [text] in German through the tutor gateway. If the gateway cannot be
/// reached the learner is told, and everything still works from the text.
class SpeakButton extends ConsumerStatefulWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.label = 'Listen',
    this.filled = false,
  });

  final String text;
  final String label;

  /// Shows a labelled button instead of an icon button.
  final bool filled;

  @override
  ConsumerState<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<SpeakButton> {
  final _player = AudioPlayerService();
  var _busy = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final audio = await ref.read(appControllerProvider).speak(widget.text);
      await _player.playBytes(audio.bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Audio needs the AI tutor connection. You can still read the text.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : const Icon(Icons.volume_up_rounded);
    if (widget.filled) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _speak,
        icon: icon,
        label: Text(widget.label),
      );
    }
    return IconButton(
      tooltip: widget.label,
      onPressed: _busy ? null : _speak,
      icon: icon,
    );
  }
}
