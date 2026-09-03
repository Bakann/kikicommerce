import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/last_sport_segment_store.dart';

/// Store for the last Sport segment the visitor browsed. Overridable in tests.
final lastSportSegmentStoreProvider = Provider<LastSportSegmentStore>(
  (ref) => SharedPreferencesLastSportSegmentStore(),
);
