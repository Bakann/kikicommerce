import 'package:shared_preferences/shared_preferences.dart';

import '../../application/storefront/storefront_sport_segment.dart';

const lastSportSegmentStorageKey = 'last_sport_segment_v1';

/// Persists the last Sport segment (Homme/Femme/Enfant) the visitor browsed.
///
/// Used so cart entry points that need a concrete Sport landing — there is no
/// bare `/sport` route, only `/sport/{segment}` — can return the visitor to
/// where they were instead of a hardcoded default.
abstract class LastSportSegmentStore {
  Future<StorefrontSportSegment?> read();
  Future<void> write(StorefrontSportSegment segment);
}

class SharedPreferencesLastSportSegmentStore implements LastSportSegmentStore {
  final SharedPreferencesAsync? _override;

  SharedPreferencesLastSportSegmentStore({SharedPreferencesAsync? preferences})
    : _override = preferences;

  SharedPreferencesAsync? _resolve() {
    if (_override != null) return _override;
    try {
      return SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StorefrontSportSegment?> read() async {
    final prefs = _resolve();
    if (prefs == null) return null;
    try {
      final value = await prefs.getString(lastSportSegmentStorageKey);
      return StorefrontSportSegment.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(StorefrontSportSegment segment) async {
    final prefs = _resolve();
    if (prefs == null) return;
    try {
      await prefs.setString(lastSportSegmentStorageKey, segment.wireName);
    } catch (_) {
      // Best-effort persistence; never throw.
    }
  }
}
