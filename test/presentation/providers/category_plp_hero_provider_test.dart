import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/category_plp_hero_provider.dart';

void main() {
  const hint = CategoryPlpHeroShuttle(
    imageUrl: 'https://example.test/tile.jpg',
  );

  testWidgets('hint persists past the keepAlive while a listener watches it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The displayed PLP hero is modelled by this listener.
    final sub = container.listen<CategoryPlpHeroShuttle?>(
      categoryPlpHeroShuttleProvider('k'),
      (_, _) {},
    );
    addTearDown(sub.close);

    container.read(categoryPlpHeroShuttleProvider('k').notifier).state = hint;
    expect(container.read(categoryPlpHeroShuttleProvider('k')), isNotNull);

    // Advance well past the keepAlive window: the release timer fires, but the
    // listener keeps the provider alive with its value intact.
    await tester.pump(
      kCategoryPlpHeroShuttleKeepAlive + const Duration(seconds: 5),
    );
    await tester.pump();

    expect(
      container.read(categoryPlpHeroShuttleProvider('k')),
      isNotNull,
      reason: 'the non-CMS hero must not vanish while the PLP is displaying it',
    );
  });
}

// Cleanup ("no stale reuse") relies on autoDispose once the PLP is left — a
// well-established Riverpod behaviour whose exact timing is fragile to assert
// under the fake-async test clock, so it is documented on the provider rather
// than pinned here. The regression that mattered (vanishing while displayed) is
// covered above.
