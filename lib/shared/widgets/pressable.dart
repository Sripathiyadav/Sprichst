import 'package:flutter/material.dart';

import 'app_widgets.dart';

/// A brief, springy shrink while a control is pressed, as on Apple platforms.
/// It listens without competing for the gesture, so the child's own `InkWell`
/// or button still receives the tap. Skipped when the system asks for reduced
/// motion.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = .97,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  var _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed && widget.enabled) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: motionDuration(context, 120),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      );
}
