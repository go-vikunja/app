import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio of [a] and [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

/// The opaque colour of the [Material] that [context] is drawn on, else the
/// theme's surface.
Color surfaceBehind(BuildContext context) {
  // Read every time, so that a change of theme draws the colour again.
  final surface = Theme.of(context).colorScheme.surface;
  final material = Material.maybeOf(context)?.color;
  return material != null && material.a == 1 ? material : surface;
}

/// [color] as drawn on [surface]: as it is when it stands out from it by
/// [minContrast], else only its lightness moved away from [surface] until
/// it does, in Oklch, which keeps hue and chroma, the chroma as far as sRGB
/// allows. Only for drawing: colour pickers show the stored colour.
Color legibleOn(Color color, Color surface, {double minContrast = 3}) {
  if (contrastRatio(color, surface) >= minContrast) return color;
  final key = (color.toARGB32(), surface.toARGB32(), minContrast);
  if (_legible[key] case final known?) return known;
  if (_legible.length >= 256) _legible.clear();
  return _legible[key] = _shifted(color, surface, minContrast);
}

/// [legibleOn] the surface of [context].
Color legibleIn(BuildContext context, Color color, {double minContrast = 3}) =>
    legibleOn(color, surfaceBehind(context), minContrast: minContrast);

final _legible = <(int, int, double), Color>{};

/// Where black and white stand out from a surface equally.
const _balancedLuminance = 0.1791;

Color _shifted(Color color, Color surface, double minContrast) {
  final (:lightness, :chroma, :hue) = _Oklch.of(color);
  final lighter = surface.computeLuminance() <= _balancedLuminance;
  // White or black, which stand out by 4.58 at least from such a surface.
  var reached = _Oklch.toColor(lighter ? 1 : 0, 0, hue, color.a);
  var near = lightness;
  var far = lighter ? 1.0 : 0.0;
  for (var step = 0; step < 24; step++) {
    final middle = (near + far) / 2;
    final candidate = _Oklch.toColor(middle, chroma, hue, color.a);
    if (contrastRatio(candidate, surface) >= minContrast) {
      reached = candidate;
      far = middle;
    } else {
      near = middle;
    }
  }
  return reached;
}

/// Björn Ottosson's Oklab (2020) in polar form, on linear sRGB.
abstract final class _Oklch {
  static ({double lightness, double chroma, double hue}) of(Color color) {
    final r = _linear(color.r);
    final g = _linear(color.g);
    final b = _linear(color.b);
    final l = _cubeRoot(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = _cubeRoot(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = _cubeRoot(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return (
      lightness: lightness,
      chroma: math.sqrt(a * a + bb * bb),
      hue: math.atan2(bb, a),
    );
  }

  /// The colour at [lightness] and [hue] with [chroma], or with the most
  /// chroma below it that sRGB holds there.
  static Color toColor(
    double lightness,
    double chroma,
    double hue,
    double alpha,
  ) {
    var rgb = _linearRgb(lightness, chroma, hue);
    if (!_inGamut(rgb)) {
      var low = 0.0;
      var high = chroma;
      for (var step = 0; step < 16; step++) {
        final middle = (low + high) / 2;
        if (_inGamut(_linearRgb(lightness, middle, hue))) {
          low = middle;
        } else {
          high = middle;
        }
      }
      rgb = _linearRgb(lightness, low, hue);
    }
    return Color.from(
      alpha: alpha,
      red: _encoded(rgb.$1),
      green: _encoded(rgb.$2),
      blue: _encoded(rgb.$3),
    );
  }

  static (double, double, double) _linearRgb(
    double lightness,
    double chroma,
    double hue,
  ) {
    final a = chroma * math.cos(hue);
    final b = chroma * math.sin(hue);
    final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
    final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
    final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
    return (
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    );
  }

  static bool _inGamut((double, double, double) rgb) {
    bool fits(double channel) => channel >= -1e-7 && channel <= 1 + 1e-7;
    return fits(rgb.$1) && fits(rgb.$2) && fits(rgb.$3);
  }

  static double _linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  static double _encoded(double linear) {
    final channel = linear.clamp(0.0, 1.0);
    final encoded = channel <= 0.0031308
        ? 12.92 * channel
        : 1.055 * math.pow(channel, 1 / 2.4) - 0.055;
    // Whole 8-bit steps, so equal colours compare equal.
    return (encoded * 255).round() / 255;
  }

  static double _cubeRoot(double value) => value < 0
      ? -math.pow(-value, 1 / 3).toDouble()
      : math.pow(value, 1 / 3).toDouble();
}
