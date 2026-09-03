import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_provider.dart';

/// State slice driving the cart nav badge and its impact pop.
class CartFlightBadgeState {
  const CartFlightBadgeState({
    required this.pendingBadgeDeferrals,
    required this.impactTick,
    required this.incomingFlightCount,
  });

  /// Card adds whose optimistic count bump is already in
  /// [cartItemCountProvider] but whose comet has not hit the icon yet — the
  /// badge subtracts these so the number appears only at impact.
  final int pendingBadgeDeferrals;

  /// Bumped once per comet impact; the cart tile plays one pop per bump.
  final int impactTick;

  /// Visual-only count of comet flights whose sticker is still travelling
  /// toward the cart. The nav icon opens while this is positive.
  final int incomingFlightCount;

  CartFlightBadgeState copyWith({
    int? pendingBadgeDeferrals,
    int? impactTick,
    int? incomingFlightCount,
  }) {
    return CartFlightBadgeState(
      pendingBadgeDeferrals:
          pendingBadgeDeferrals ?? this.pendingBadgeDeferrals,
      impactTick: impactTick ?? this.impactTick,
      incomingFlightCount: incomingFlightCount ?? this.incomingFlightCount,
    );
  }
}

/// Coordinates an add-to-cart comet flight between its trigger (the PLP
/// product card) and its target (the cart tile in the bottom nav).
///
/// Three responsibilities:
/// 1. **Anchor registry** — mounted cart tiles register a global-rect
///    resolver; a flight resolves its target ONCE at launch. A registry (not
///    a shared GlobalKey) because go_router `push` can keep two navs mounted
///    at once, and a shared key would throw "Duplicate GlobalKey".
/// 2. **Badge deferral** — the optimistic add bumps the cart count long
///    before the comet lands (~680 ms later); [pendingBadgeDeferrals] masks
///    the bump until impact so the macaron pops exactly when the comet hits.
/// 3. **Impact pop** — [impactTick] tells the cart tile to play its one-shot
///    squash/glow, and only when the add actually succeeded.
///
/// Per-flight state machine: a deferral is taken only in [onFlightAddLanded]
/// (i.e. only once the count really contains the new item, so the badge never
/// under-reports), released with a tick at impact, or released silently by
/// [onFlightDisposed] if the flight ends without impacting (safety teardown).
/// A slow add that lands after the impact pops immediately, unmasked. A
/// failed add never pops and never touches the deferral.
class CartFlightCoordinator extends Notifier<CartFlightBadgeState> {
  final List<_CartAnchor> _anchors = <_CartAnchor>[];
  final Map<int, _FlightRecord> _flights = <int, _FlightRecord>{};
  int _nextFlightId = 0;

  @override
  CartFlightBadgeState build() {
    return const CartFlightBadgeState(
      pendingBadgeDeferrals: 0,
      impactTick: 0,
      incomingFlightCount: 0,
    );
  }

  // ---- Anchor registry (plain fields, not state: geometry, not UI data) ----

  void registerCartAnchor(Object owner, Rect? Function() resolveGlobalRect) {
    unregisterCartAnchor(owner);
    _anchors.add(_CartAnchor(owner, resolveGlobalRect));
  }

  void unregisterCartAnchor(Object owner) {
    _anchors.removeWhere((anchor) => anchor.owner == owner);
  }

  /// Most recently registered anchor that can currently resolve; null when no
  /// cart tile is on screen (the flight is skipped in that case).
  Rect? resolveCartTargetRect() {
    for (var i = _anchors.length - 1; i >= 0; i--) {
      final rect = _anchors[i].resolveGlobalRect();
      if (rect != null && !rect.isEmpty) return rect;
    }
    return null;
  }

  // ---- Flight lifecycle ----

  int startFlight() {
    final id = ++_nextFlightId;
    _flights[id] = _FlightRecord()..receptionHeld = true;
    state = state.copyWith(incomingFlightCount: state.incomingFlightCount + 1);
    return id;
  }

  /// The optimistic add has been applied to the cart state (count bumped).
  void onFlightAddLanded(int id) {
    final flight = _flights[id];
    if (flight == null || flight.landed || flight.failed) return;
    flight.landed = true;
    if (flight.impactReached) {
      // Slow add (addProduct awaits the network ACK): the comet already hit
      // — possibly the whole overlay is already gone. Pop now, never mask.
      state = state.copyWith(impactTick: state.impactTick + 1);
    } else if (!flight.disposed) {
      flight.deferralHeld = true;
      state = state.copyWith(
        pendingBadgeDeferrals: state.pendingBadgeDeferrals + 1,
      );
    }
    _removeIfSettled(id, flight);
  }

  void onFlightAddFailed(int id) {
    final flight = _flights[id];
    if (flight == null || flight.landed || flight.failed) return;
    flight.failed = true;
    _releaseDeferral(flight);
    _removeIfSettled(id, flight);
  }

  /// The comet head reached the icon (~80% of the flight).
  void onFlightImpact(int id) {
    final flight = _flights[id];
    if (flight == null || flight.impactReached) return;
    flight.impactReached = true;
    if (flight.deferralHeld) {
      flight.deferralHeld = false;
      state = CartFlightBadgeState(
        pendingBadgeDeferrals: state.pendingBadgeDeferrals - 1,
        impactTick: state.impactTick + 1,
        incomingFlightCount: state.incomingFlightCount,
      );
    }
  }

  /// Always called when the overlay is torn down, whatever happened before.
  /// Releases a still-held deferral silently so the badge can never stay
  /// masked after its flight is gone. The record itself survives while the
  /// async add outcome is still pending, so a slow success arriving after
  /// the visual end can still pop the icon (see [onFlightAddLanded]).
  void onFlightDisposed(int id) {
    final flight = _flights[id];
    if (flight == null || flight.disposed) return;
    flight.disposed = true;
    _releaseDeferral(flight);
    _releaseReception(flight);
    _removeIfSettled(id, flight);
  }

  /// A record is dropped only once both lifecycles are over: the overlay is
  /// disposed AND the add outcome (landed/failed) is known.
  void _removeIfSettled(int id, _FlightRecord flight) {
    if (flight.disposed && (flight.landed || flight.failed)) {
      _flights.remove(id);
    }
  }

  void _releaseDeferral(_FlightRecord flight) {
    if (!flight.deferralHeld) return;
    flight.deferralHeld = false;
    state = state.copyWith(
      pendingBadgeDeferrals: state.pendingBadgeDeferrals - 1,
    );
  }

  void _releaseReception(_FlightRecord flight) {
    if (!flight.receptionHeld) return;
    flight.receptionHeld = false;
    final nextIncoming = state.incomingFlightCount <= 0
        ? 0
        : state.incomingFlightCount - 1;
    state = state.copyWith(incomingFlightCount: nextIncoming);
  }
}

class _CartAnchor {
  const _CartAnchor(this.owner, this.resolveGlobalRect);

  final Object owner;
  final Rect? Function() resolveGlobalRect;
}

class _FlightRecord {
  bool landed = false;
  bool failed = false;
  bool impactReached = false;
  bool deferralHeld = false;
  bool receptionHeld = false;
  bool disposed = false;
}

final cartFlightCoordinatorProvider =
    NotifierProvider<CartFlightCoordinator, CartFlightBadgeState>(
      CartFlightCoordinator.new,
    );

/// What the cart macaron actually renders: the real count minus the adds
/// whose comet is still in the air. Identical to [cartItemCountProvider]
/// whenever nothing is in flight.
final displayedCartBadgeCountProvider = Provider<int>((ref) {
  final count = ref.watch(cartItemCountProvider);
  final pending = ref.watch(
    cartFlightCoordinatorProvider.select((s) => s.pendingBadgeDeferrals),
  );
  if (pending <= 0) return count;
  return (count - pending).clamp(0, count);
});
