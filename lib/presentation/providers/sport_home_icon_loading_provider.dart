import 'package:flutter_riverpod/legacy.dart';

/// Whether the Sport bottom nav Home glyph should show its loading animation.
///
/// This is visual state shared with [SportFlowShell], which owns the persistent
/// bottom nav above landing and PLP route children.
final sportHomeIconLoadingProvider = StateProvider<bool>((ref) => false);
