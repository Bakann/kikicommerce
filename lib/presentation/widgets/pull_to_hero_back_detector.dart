import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Toggle to print the gesture lifecycle while debugging. Compiled out of
/// release builds via [kReleaseMode]; left `false` so it never spams the
/// console by default.
const bool _kDebugPullToHeroBack = false;

/// Wraps the PDP's primary scrollable and pops the route when the user, while
/// already at the very top, drags downward past [threshold].
///
/// The pop drives the shared product-image Hero back to the PLP card. The
/// detection is purely event-driven: it never calls `setState`, never measures
/// layout, and returns `false` from the listener so normal scroll propagation
/// (purchase-bar anchoring, etc.) is untouched.
class PullToHeroBackDetector extends StatefulWidget {
  const PullToHeroBackDetector({
    super.key,
    required this.child,
    required this.onTrigger,
    this.threshold = 80,
  });

  final Widget child;

  /// Invoked once per gesture when the cumulative downward overscroll crosses
  /// [threshold]. The callback owns the navigation guards (canPop, in-flight
  /// transition checks).
  final VoidCallback onTrigger;

  /// Cumulative downward overscroll (logical px) required to fire. Kept high
  /// enough that a stray bounce at the top does not pop the page.
  final double threshold;

  @override
  State<PullToHeroBackDetector> createState() => _PullToHeroBackDetectorState();
}

class _PullToHeroBackDetectorState extends State<PullToHeroBackDetector> {
  // Treat anything within 1px of the top as "at the top" to absorb rounding.
  static const double _topEpsilon = 1;

  double _accumulatedPull = 0;
  bool _hasTriggered = false;

  bool _handleNotification(ScrollNotification notification) {
    // Only the root vertical scrollable matters; ignore nested scrollers
    // (carousel page view, cross-sell rows) and horizontal axes.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _reset();
      return false;
    }

    if (notification is OverscrollNotification) {
      // `dragDetails == null` means wheel/trackpad/programmatic overscroll —
      // never pop on those, only on a genuine touch drag.
      if (notification.dragDetails == null) return false;

      final atTop =
          notification.metrics.pixels <=
          notification.metrics.minScrollExtent + _topEpsilon;
      if (!atTop) {
        _accumulatedPull = 0;
        return false;
      }

      // overscroll < 0 == pulling the content down past the top edge.
      if (notification.overscroll < 0) {
        _accumulatedPull += -notification.overscroll;
        _debug('accumulated=$_accumulatedPull');
        _maybeTrigger();
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // Scrolled away from the top during a normal downward read: abandon any
      // partial accumulation so the next return-to-top starts fresh.
      final pastTop =
          notification.metrics.pixels >
          notification.metrics.minScrollExtent + _topEpsilon;
      if (pastTop) _accumulatedPull = 0;
      return false;
    }

    if (notification is ScrollEndNotification) {
      _reset();
      return false;
    }

    return false;
  }

  void _maybeTrigger() {
    if (_hasTriggered || _accumulatedPull < widget.threshold) return;
    _hasTriggered = true;
    _accumulatedPull = 0;
    _debug('threshold reached -> onTrigger');
    widget.onTrigger();
  }

  void _reset() {
    _accumulatedPull = 0;
    _hasTriggered = false;
  }

  void _debug(String message) {
    if (!_kDebugPullToHeroBack) return;
    assert(() {
      debugPrint('[pull-to-hero-back] $message');
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: widget.child,
    );
  }
}
