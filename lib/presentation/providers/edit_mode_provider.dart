import 'package:flutter_riverpod/legacy.dart';

final editModeProvider = StateProvider<bool>((ref) => false);
final editControlsVisibleProvider = StateProvider<bool>((ref) => false);
final adminAuthTokenProvider = StateProvider<String?>((ref) => null);
