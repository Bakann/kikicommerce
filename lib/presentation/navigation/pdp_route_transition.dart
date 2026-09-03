import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/pdp_water_ripple_image.dart';

/// Shared PDP route transition (fade + subtle upward slide) used by the
/// PocketBase product routes and the commercetools lab PDP, so both feel
/// identical. Lives in `presentation/navigation` (not `lib/app`) so feature
/// modules can depend on it without importing the composition root.
class PdpContentTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const PdpContentTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final page = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    final offset = Tween<Offset>(
      begin: const Offset(0, 0.012),
      end: Offset.zero,
    ).animate(page);

    return FadeTransition(
      opacity: page,
      child: SlideTransition(position: offset, child: child),
    );
  }
}

/// Builds a [CustomTransitionPage] with the standard PDP timings and the
/// [PdpContentTransition] (honouring reduced-motion).
CustomTransitionPage<void> pdpTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    child: PdpWaterRippleRouteScope(child: child),
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return child;
      }
      return PdpContentTransition(animation: animation, child: child);
    },
  );
}
