import 'dart:ui';

/// Parses a CMS-config hex color (`#RRGGBB`, `RRGGBB` or `#AARRGGBB`) into a
/// [Color]. Returns null for anything malformed so callers can fall back to
/// their default palette instead of painting garbage.
Color? cmsColorFromHex(String? raw) {
  final value = raw?.trim().replaceFirst('#', '') ?? '';
  if (value.length != 6 && value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(value.length == 6 ? (0xFF000000 | parsed) : parsed);
}

/// Formats a [Color] back into the `#RRGGBB` form stored in section configs.
String cmsHexFromColor(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
