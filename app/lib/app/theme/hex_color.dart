import 'dart:ui';

final _sixHexDigits = RegExp(r'^[0-9a-fA-F]{6}$');

/// Vikunja's `rrggbb` colours, with or without `#`; null for anything else.
Color? parseHexColor(String hex) {
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  if (!_sixHexDigits.hasMatch(digits)) return null;
  return Color(0xFF000000 | int.parse(digits, radix: 16));
}

/// The web's `getTextColor`: black on light backgrounds, white otherwise,
/// with the same luminance threshold so chips look alike on both clients.
Color contrastingTextColor(Color background) =>
    background.computeLuminance() > 0.1791
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);
