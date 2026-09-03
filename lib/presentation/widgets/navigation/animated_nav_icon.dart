import 'package:flutter/material.dart';

/// Wraps a bottom-nav tile's icon with a lightweight, hand-rolled activation
/// pulse (a subtle scale-up + vertical lift) — no animated-icon package
/// (Rive/Lottie/etc.).
///
/// The pulse is driven by a single [AnimationController] through an
/// [AnimatedBuilder] + [Transform], inside a [RepaintBoundary]. It is therefore
/// confined to this tile: the surrounding navbar never rebuilds or repaints per
/// frame. The wrapped [child] (icon + optional badge) moves as one unit.
///
/// Fires when the tile transitions to active, and whenever [playToken] changes
/// (the parent bumps it on each tap, so a re-tap on the already-active tile
/// still pulses). Honors reduced-motion: when animations are disabled the
/// [child] is rendered as-is and the controller is never started.
class AnimatedNavIcon extends StatefulWidget {
  final Widget child;
  final bool isActive;

  /// Incremented by the parent on each tap to re-trigger the pulse even when
  /// the tile is already active (no active-state transition occurs then).
  final int playToken;

  const AnimatedNavIcon({
    super.key,
    required this.child,
    required this.isActive,
    required this.playToken,
  });

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with SingleTickerProviderStateMixin {
  // Created in initState (not an inline late init) so dispose() can always
  // dispose it safely, even if this state is torn down before its first build.
  late final AnimationController _controller;

  // Rise on easeOutBack (a touch of premium overshoot), settle on easeOutCubic
  // so the icon never dips below its resting scale/position.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.12,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.12,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 55,
    ),
  ]).animate(_controller);

  late final Animation<double> _lift = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: -3,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: -3,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 55,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void didUpdateWidget(AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive = widget.isActive && !oldWidget.isActive;
    final tapped = widget.playToken != oldWidget.playToken;
    if (becameActive || tapped) {
      _play();
    }
  }

  void _play() {
    // Reduced-motion: skip the pulse entirely (no ticker work).
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion: render the static child, no AnimatedBuilder / Transform.
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        // `child` is built once; only the Transforms recompute per frame.
        child: widget.child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _lift.value),
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
      ),
    );
  }
}
