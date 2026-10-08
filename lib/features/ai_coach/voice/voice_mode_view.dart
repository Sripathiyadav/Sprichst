import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/breakpoints.dart';
import '../../../domain/models/learning_models.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'voice_adapters.dart';
import 'voice_session.dart';

/// Hands-free conversation with the tutor. Opens already listening: talk,
/// pause, and the tutor answers aloud and listens again, with no button in
/// between. Pops with the turns that happened so the Coach can keep them.
class VoiceModeView extends ConsumerStatefulWidget {
  const VoiceModeView({super.key, this.session});

  /// For tests: a ready-made session. The view starts and stops it but does
  /// not create the microphone and speaker itself.
  final VoiceSession? session;

  @override
  ConsumerState<VoiceModeView> createState() => _VoiceModeViewState();
}

class _VoiceModeViewState extends ConsumerState<VoiceModeView>
    with WidgetsBindingObserver {
  late final VoiceSession _session;
  MicrophoneRecorder? _recorder;
  SpeakerOutput? _speaker;
  final _scroll = ScrollController();
  var _turnCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.session;
    if (injected != null) {
      _session = injected;
    } else {
      final app = ref.read(appControllerProvider);
      _recorder = MicrophoneRecorder();
      _speaker = SpeakerOutput();
      _session = VoiceSession(
        recorder: _recorder!,
        output: _speaker!,
        backend: AppVoiceBackend(app),
        endSilence: Duration(milliseconds: app.profile!.voicePauseMs),
      );
    }
    _session.addListener(_onChanged);
    _session.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onChanged);
    if (widget.session == null) {
      _session.dispose();
      _recorder?.dispose();
      _speaker?.dispose();
    } else {
      _session.stop();
    }
    _scroll.dispose();
    super.dispose();
  }

  /// The microphone must not stay open when the app is not on screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _session.isActive) {
      _session.pause();
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (_session.turns.length != _turnCount) {
      _turnCount = _session.turns.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: motionDuration(context, 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _end() async {
    await _session.stop();
    if (mounted) Navigator.of(context).pop(_session.turns);
  }

  void _toggleListening() {
    if (_session.phase == VoicePhase.paused) {
      _session.resume();
    } else {
      _session.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = _session.phase;
    final paused = phase == VoicePhase.paused;
    final status = _statusOf(phase);
    final voiceName = widget.session != null
        ? null
        : VoiceList.offline
            .labelOf(ref.watch(appControllerProvider).profile!.voice);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _toggleListening,
          const SingleActivator(LogicalKeyboardKey.escape): _end,
        },
        child: Focus(
          autofocus: true,
          child: GlassPage(
            appBar: AppBar(
              title: const Text('Voice mode'),
              leading: IconButton(
                tooltip: 'End conversation',
                onPressed: _end,
                icon: const Icon(Icons.close),
              ),
              actions: [
                if (voiceName != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: Chip(
                        avatar: const Icon(Icons.record_voice_over_outlined,
                            size: 18),
                        label: Text(voiceName),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: Breakpoints.lessonMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        _Orb(session: _session),
                        const SizedBox(height: AppSpacing.sm),
                        Semantics(
                          liveRegion: true,
                          child: Text(status.title,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center),
                        ),
                        Text(status.hint,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                        if (_session.notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: SoftCard(
                              color: context.dangerSurface,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Text(
                                _session.notice!,
                                style:
                                    TextStyle(color: context.onDangerSurface),
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                            child: _Transcript(
                                session: _session, controller: _scroll)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundButton(
                              label: paused
                                  ? 'Resume listening'
                                  : 'Pause listening',
                              icon: paused ? Icons.mic : Icons.mic_off_outlined,
                              filled: paused,
                              onPressed: _toggleListening,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _RoundButton(
                              label: 'Skip the tutor\'s reply',
                              icon: Icons.skip_next_rounded,
                              onPressed: phase == VoicePhase.speaking
                                  ? _session.skip
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _RoundButton(
                              label: 'End conversation',
                              icon: Icons.call_end_rounded,
                              danger: true,
                              onPressed: _end,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({String title, String hint}) _statusOf(VoicePhase phase) => switch (phase) {
        VoicePhase.idle => (title: 'Ready', hint: 'Starting the microphone…'),
        VoicePhase.listening => (
            title: 'Listening…',
            hint: 'Just speak German. Pause when you are done.'
          ),
        VoicePhase.hearing => (
            title: 'I hear you',
            hint: 'Pause when you are finished.'
          ),
        VoicePhase.transcribing => (title: 'Understanding…', hint: ' '),
        VoicePhase.thinking => (title: 'Thinking…', hint: ' '),
        VoicePhase.speaking => (
            title: 'Your tutor is speaking',
            hint: 'Listen, then answer.'
          ),
        VoicePhase.paused => (
            title: 'Paused',
            hint: 'Tap the microphone or press Space to continue.'
          ),
      };
}

/// The big circle: grows with your voice while you speak, pulses while the
/// tutor thinks or talks, and sits still when paused.
class _Orb extends StatefulWidget {
  const _Orb({required this.session});

  final VoiceSession session;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData _icon(VoicePhase phase) => switch (phase) {
        VoicePhase.hearing => Icons.graphic_eq_rounded,
        VoicePhase.transcribing ||
        VoicePhase.thinking =>
          Icons.more_horiz_rounded,
        VoicePhase.speaking => Icons.volume_up_rounded,
        VoicePhase.paused => Icons.mic_off_rounded,
        _ => Icons.mic_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: 180,
        width: 180,
        child: ListenableBuilder(
          listenable:
              Listenable.merge([widget.session, widget.session.level, _pulse]),
          builder: (context, _) {
            final phase = widget.session.phase;
            final level = widget.session.level.value;
            final breathing = phase == VoicePhase.thinking ||
                phase == VoicePhase.transcribing ||
                phase == VoicePhase.speaking;
            final wave = reduceMotion ? .5 : _pulse.value;
            final double scale = switch (phase) {
              VoicePhase.listening ||
              VoicePhase.hearing =>
                1.0 + (reduceMotion ? 0.0 : level * .45),
              _ when breathing => 1.0 + wave * .12,
              _ => 1.0,
            };
            final color =
                phase == VoicePhase.paused ? scheme.outline : context.accent;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale * 1.18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: .16),
                    ),
                    child: const SizedBox(width: 130, height: 130),
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .35),
                          blurRadius: 24,
                          spreadRadius: math.max(0.0, level * 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child:
                          Icon(_icon(phase), size: 52, color: context.onAccent),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.session, required this.controller});

  final VoiceSession session;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turns = session.turns;
    if (turns.isEmpty) {
      return Center(
        child: Text(
          'Try: “Hallo! Ich möchte heute über mein Wochenende sprechen.”',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: turns.length,
      itemBuilder: (context, i) {
        final turn = turns[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _Bubble(text: turn.user, mine: true),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: _Bubble(text: turn.tutor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, this.mine = false});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Breakpoints.messageMaxWidth),
      child: Semantics(
        label: '${mine ? 'You' : 'Tutor'}: $text',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              text,
              style: TextStyle(
                color: mine ? scheme.onPrimary : scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = IconButton.styleFrom(
      minimumSize: const Size(60, 60),
      backgroundColor: danger
          ? scheme.error
          : filled
              ? scheme.primary
              : null,
      foregroundColor: danger
          ? scheme.onError
          : filled
              ? scheme.onPrimary
              : null,
    );
    return danger || filled
        ? IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: 28),
            style: style,
          )
        : IconButton.outlined(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: 28),
            style: style,
          );
  }
}
