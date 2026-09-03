import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/scroll_navbar_state_machine.dart';

void main() {
  group('ScrollNavbarStateMachine', () {
    test('initial offset 0 is visible with hero style', () {
      final machine = ScrollNavbarStateMachine();

      final snapshot = machine.update(offset: 0, heroHeight: 600);

      expect(snapshot.isVisible, isTrue);
      expect(snapshot.styleProgress, 0);
    });

    test('scroll down past threshold hides the navbar', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600);

      final snapshot = machine.update(offset: 32, heroHeight: 600);

      expect(snapshot.isVisible, isFalse);
    });

    test('cumulative small downward scroll hides after leaving top zone', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600)
        ..update(offset: 2, heroHeight: 600)
        ..update(offset: 6, heroHeight: 600)
        ..update(offset: 10, heroHeight: 600)
        ..update(offset: 12, heroHeight: 600)
        ..update(offset: 14, heroHeight: 600)
        ..update(offset: 16, heroHeight: 600)
        ..update(offset: 18, heroHeight: 600);

      final snapshot = machine.update(offset: 21, heroHeight: 600);

      expect(snapshot.isVisible, isFalse);
    });

    test('scroll up past threshold shows the navbar', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600)
        ..update(offset: 48, heroHeight: 600);

      final snapshot = machine.update(offset: 36, heroHeight: 600);

      expect(snapshot.isVisible, isTrue);
    });

    test('cumulative small upward scroll shows the navbar', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600)
        ..update(offset: 48, heroHeight: 600)
        ..update(offset: 46, heroHeight: 600)
        ..update(offset: 44, heroHeight: 600);

      final snapshot = machine.update(offset: 41, heroHeight: 600);

      expect(snapshot.isVisible, isTrue);
    });

    test('micro scroll under thresholds does not change visibility', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600)
        ..update(offset: 32, heroHeight: 600);

      final snapshot = machine.update(offset: 36, heroHeight: 600);

      expect(snapshot.isVisible, isFalse);
    });

    test('heroHeight <= 0 forces light style', () {
      final machine = ScrollNavbarStateMachine();

      final snapshot = machine.update(offset: 0, heroHeight: 0);

      expect(snapshot.isVisible, isTrue);
      expect(snapshot.styleProgress, 1);
    });

    test('offset beyond hero transition forces light style', () {
      final machine = ScrollNavbarStateMachine();

      final snapshot = machine.update(offset: 600, heroHeight: 600);

      expect(snapshot.styleProgress, 1);
    });

    test('edit mode forces visible light style', () {
      final machine = ScrollNavbarStateMachine()
        ..update(offset: 0, heroHeight: 600)
        ..update(offset: 48, heroHeight: 600);

      final snapshot = machine.update(
        offset: 240,
        heroHeight: 600,
        forceVisibleLight: true,
      );

      expect(snapshot.isVisible, isTrue);
      expect(snapshot.styleProgress, 1);
    });
  });
}
