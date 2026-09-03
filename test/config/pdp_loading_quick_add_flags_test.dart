import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/config/pdp_loading_quick_add_flags.dart';

void main() {
  test('PDP loading quick add is enabled by default', () {
    expect(PdpLoadingQuickAddFlags.enabled, isTrue);
  });
}
