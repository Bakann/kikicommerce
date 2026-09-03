import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/cart_flight_coordinator_provider.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer({int liveCount = 0}) {
    final container = ProviderContainer(
      overrides: [liveCartItemCountProvider.overrideWithValue(liveCount)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('badge deferral state machine', () {
    test('at rest the displayed count is the plain cart count', () {
      final container = makeContainer(liveCount: 3);
      expect(container.read(displayedCartBadgeCountProvider), 3);
      expect(
        container.read(cartFlightCoordinatorProvider).pendingBadgeDeferrals,
        0,
      );
      expect(
        container.read(cartFlightCoordinatorProvider).incomingFlightCount,
        0,
      );
    });

    test('start and dispose drive the visual reception state', () {
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      expect(
        container.read(cartFlightCoordinatorProvider).incomingFlightCount,
        1,
      );

      coordinator.onFlightImpact(id);
      expect(
        container.read(cartFlightCoordinatorProvider).incomingFlightCount,
        1,
      );

      coordinator.onFlightDisposed(id);
      expect(
        container.read(cartFlightCoordinatorProvider).incomingFlightCount,
        0,
      );
    });

    test('landed then impact: masks the bump, releases it with one tick', () {
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      // The optimistic add landed: count already includes the new item, the
      // badge shows the pre-add value until impact.
      coordinator.onFlightAddLanded(id);
      expect(container.read(displayedCartBadgeCountProvider), 2);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 0);

      coordinator.onFlightImpact(id);
      expect(container.read(displayedCartBadgeCountProvider), 3);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 1);

      coordinator.onFlightDisposed(id);
      expect(container.read(displayedCartBadgeCountProvider), 3);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 1);
    });

    test('slow add landing after impact pops immediately, never masks', () {
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightImpact(id);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 0);
      expect(container.read(displayedCartBadgeCountProvider), 3);

      coordinator.onFlightAddLanded(id);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 1);
      expect(container.read(displayedCartBadgeCountProvider), 3);

      coordinator.onFlightDisposed(id);
      expect(
        container.read(cartFlightCoordinatorProvider).pendingBadgeDeferrals,
        0,
      );
    });

    test('failed add: no tick, deferral untouched', () {
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightAddFailed(id);
      coordinator.onFlightImpact(id);
      coordinator.onFlightDisposed(id);

      final state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);
      expect(container.read(displayedCartBadgeCountProvider), 3);
    });

    test(
      'disposed without impact releases the mask silently, exactly once',
      () {
        final container = makeContainer(liveCount: 3);
        final coordinator = container.read(
          cartFlightCoordinatorProvider.notifier,
        );

        final id = coordinator.startFlight();
        coordinator.onFlightAddLanded(id);
        expect(container.read(displayedCartBadgeCountProvider), 2);

        coordinator.onFlightDisposed(id);
        var state = container.read(cartFlightCoordinatorProvider);
        expect(state.pendingBadgeDeferrals, 0);
        expect(state.impactTick, 0);

        // Idempotent: a second dispose (or a late impact) cannot double
        // decrement or pop.
        coordinator.onFlightDisposed(id);
        coordinator.onFlightImpact(id);
        state = container.read(cartFlightCoordinatorProvider);
        expect(state.pendingBadgeDeferrals, 0);
        expect(state.impactTick, 0);
      },
    );

    test('slow add landing after the overlay is gone still pops', () {
      // addProduct awaits the network ACK, so it can resolve after the
      // 850 ms flight has been disposed. The impact was reached, so the
      // late success must still celebrate — exactly once.
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightImpact(id);
      coordinator.onFlightDisposed(id);
      var state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);

      coordinator.onFlightAddLanded(id);
      state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 1);
      expect(state.pendingBadgeDeferrals, 0);

      // The record is settled and dropped: replays are no-ops.
      coordinator.onFlightAddLanded(id);
      coordinator.onFlightDisposed(id);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 1);
    });

    test('add landing after disposal without impact stays silent', () {
      // Flight torn down before the comet ever hit (e.g. route destroyed):
      // the late success just lets the count update, no pop, no mask.
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightDisposed(id);
      coordinator.onFlightAddLanded(id);

      final state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);
      expect(container.read(displayedCartBadgeCountProvider), 3);
    });

    test('failed add landing after disposal stays silent', () {
      final container = makeContainer(liveCount: 3);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightImpact(id);
      coordinator.onFlightDisposed(id);
      coordinator.onFlightAddFailed(id);

      final state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);
    });

    test('displayed count never goes negative (external cart shrink)', () {
      // The cart page could empty the cart while a flight is masked.
      final container = makeContainer(liveCount: 0);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final id = coordinator.startFlight();
      coordinator.onFlightAddLanded(id);
      expect(container.read(displayedCartBadgeCountProvider), 0);
      coordinator.onFlightDisposed(id);
    });

    test('two interleaved flights keep independent state', () {
      final container = makeContainer(liveCount: 5);
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );

      final first = coordinator.startFlight();
      final second = coordinator.startFlight();
      coordinator.onFlightAddLanded(first);
      coordinator.onFlightAddLanded(second);
      expect(container.read(displayedCartBadgeCountProvider), 3);

      coordinator.onFlightImpact(first);
      expect(container.read(displayedCartBadgeCountProvider), 4);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 1);

      coordinator.onFlightImpact(second);
      expect(container.read(displayedCartBadgeCountProvider), 5);
      expect(container.read(cartFlightCoordinatorProvider).impactTick, 2);

      coordinator.onFlightDisposed(first);
      coordinator.onFlightDisposed(second);
      expect(
        container.read(cartFlightCoordinatorProvider).pendingBadgeDeferrals,
        0,
      );
    });
  });

  group('anchor registry', () {
    test('empty registry resolves to null', () {
      final container = makeContainer();
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );
      expect(coordinator.resolveCartTargetRect(), isNull);
    });

    test('latest registered anchor wins; unregister falls back', () {
      final container = makeContainer();
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );
      final ownerA = Object();
      final ownerB = Object();
      const rectA = Rect.fromLTWH(0, 0, 24, 24);
      const rectB = Rect.fromLTWH(100, 100, 24, 24);

      coordinator.registerCartAnchor(ownerA, () => rectA);
      coordinator.registerCartAnchor(ownerB, () => rectB);
      expect(coordinator.resolveCartTargetRect(), rectB);

      coordinator.unregisterCartAnchor(ownerB);
      expect(coordinator.resolveCartTargetRect(), rectA);

      coordinator.unregisterCartAnchor(ownerA);
      expect(coordinator.resolveCartTargetRect(), isNull);
    });

    test('skips anchors that currently resolve to null or empty', () {
      final container = makeContainer();
      final coordinator = container.read(
        cartFlightCoordinatorProvider.notifier,
      );
      const rect = Rect.fromLTWH(0, 0, 24, 24);

      coordinator.registerCartAnchor(Object(), () => rect);
      coordinator.registerCartAnchor(Object(), () => null);
      coordinator.registerCartAnchor(Object(), () => Rect.zero);
      expect(coordinator.resolveCartTargetRect(), rect);
    });
  });
}
