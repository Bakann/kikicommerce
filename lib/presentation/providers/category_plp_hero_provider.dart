import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

/// How long the carried hint is force-kept-alive to bridge the gap between
/// "set on tile tap" and "first watched by the destination PLP hero". A few
/// seconds amply covers the precache + navigation + first frame; the PLP's own
/// listener then keeps it alive for as long as the hero is displayed.
const kCategoryPlpHeroShuttleKeepAlive = Duration(seconds: 5);

/// The image carried from a tapped category tile to the destination PLP hero so
/// the Hero flight's first frame paints synchronously (the destination PLP
/// resolves async, exactly like the PLP→PDP `listingMedia` hint).
class CategoryPlpHeroShuttle {
  /// Listing-sized image URL the source tile already rendered. Reused verbatim
  /// for the warmed shuttle so no new variant is fetched mid-flight.
  final String imageUrl;

  const CategoryPlpHeroShuttle({required this.imageUrl});
}

/// Transient hint keyed by the shared slug key (see [categoryPlpHeroKeyFromHref]).
/// Set on tile tap, read by the destination PLP hero.
///
/// The timer only RELEASES the keepAlive — it must NOT clear the value. On a
/// non-CMS PLP the hero is sourced entirely from this hint; clearing it while
/// the PLP is still on screen made the hero vanish and the page reflow after a
/// few seconds. Instead: the keepAlive bridges the set→watch gap, then the PLP's
/// own listener keeps the hint alive for as long as the hero is displayed. Once
/// the user leaves the PLP (no listeners, keepAlive released) it auto-disposes,
/// so a stale tile image can't resurface on a later, unrelated visit.
final categoryPlpHeroShuttleProvider = StateProvider.autoDispose
    .family<CategoryPlpHeroShuttle?, String>((ref, slugKey) {
      final keepAliveLink = ref.keepAlive();
      final releaseTimer = Timer(
        kCategoryPlpHeroShuttleKeepAlive,
        keepAliveLink.close,
      );
      ref.onDispose(releaseTimer.cancel);
      return null;
    });
