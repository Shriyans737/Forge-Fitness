import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';

class HealthSyncButton extends StatefulWidget {
  const HealthSyncButton({
    required this.isSyncing,
    required this.onPressed,
    super.key,
  });

  final bool isSyncing;
  final VoidCallback onPressed;

  @override
  State<HealthSyncButton> createState() => _HealthSyncButtonState();
}

class _HealthSyncButtonState extends State<HealthSyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: ForgeMotion.settingsSyncSpin,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _setRotationState();
    }
  }

  @override
  void initState() {
    super.initState();
    _setRotationState();
  }

  @override
  void didUpdateWidget(covariant HealthSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSyncing != widget.isSyncing) _setRotationState();
  }

  void _setRotationState() {
    if (widget.isSyncing && !_reduceMotion) {
      if (!_rotation.isAnimating) _rotation.forward(from: 0);
    } else {
      _rotation
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Sync Apple Health',
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    padding: EdgeInsets.zero,
    onPressed: widget.isSyncing
        ? null
        : () {
            HapticFeedback.lightImpact();
            if (!_reduceMotion) _rotation.forward(from: 0);
            widget.onPressed();
          },
    icon: AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) => Transform.rotate(
        angle: _rotation.value * 6.283185307179586,
        child: child,
      ),
      child: const Icon(Icons.sync_rounded, size: 22),
    ),
  );
}
