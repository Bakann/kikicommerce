import 'package:flutter/widgets.dart';

/// Whether the route hosting [context] is actually on top — i.e. visible and not
/// covered by anything pushed above it, **across nested navigators**.
///
/// A plain `ModalRoute.of(context)?.isCurrent` only inspects the *nearest*
/// navigator, so a page inside a `ShellRoute`'s nested navigator would still
/// read as "current" even when the whole shell is covered by a route pushed on
/// the root navigator. This walks up through every enclosing navigator and
/// requires each hosting route to be the top of its own navigator, so a cover at
/// any level reads correctly. For a non-nested route the result is identical to
/// the simple check.
///
/// Used to gate background work (segment/luxe prewarm, drawer warm-up) so it
/// never runs for a landing that has been navigated away from / covered.
bool isCurrentRoute(BuildContext context) {
  BuildContext? cursor = context;
  while (cursor != null) {
    final route = ModalRoute.of(cursor);
    if (route == null) return true; // No enclosing route: treat as visible.
    if (!route.isCurrent) return false; // Covered in this navigator.
    // Hop above this route's navigator to check the route that hosts it.
    cursor = route.navigator?.context;
  }
  return true;
}
