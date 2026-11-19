import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

/// Floating snackbars at most [ReadableWidth.snackBar] wide with their
/// margins, centred in the scaffold that shows them, on large windows only
/// ([WindowLayout.capsWidths]); otherwise as wide as the scaffold less
/// Flutter's margins.
///
/// A scaffold draws a snackbar wider than itself edge to edge, so the width
/// comes from the room this widget is given: it sits right above every
/// scaffold that shows snackbars and is narrower than the window (the
/// shell's beside the rail, the task pane's), and [ReadableSnackBars.window]
/// above the root navigator, whose pages span the window. Each starts again
/// from [ThemeData.snackBarTheme], so a narrow scaffold drops the width set
/// for a wider one around it. Sheets need none: wherever the width applies
/// they are at least [ReadableWidth.snackBar] wide.
class ReadableSnackBars extends StatelessWidget {
  const new({required this.child, super.key}) : _ofWindow = false;

  const new window({required this.child, super.key}) : _ofWindow = true;

  final Widget child;
  final bool _ofWindow;

  /// The side margin Flutter gives a floating snackbar.
  static const _flutterMargin = 15.0;

  static SnackBarThemeData themeFor(
    SnackBarThemeData base, {
    required double available,
    required bool caps,
  }) {
    final inset = ReadableWidth.insetFor(
      available: available,
      max: ReadableWidth.snackBar,
      caps: caps,
    );
    if (inset == 0) return base;
    final margins = base.insetPadding?.horizontal ?? 2 * _flutterMargin;
    return base.copyWith(width: ReadableWidth.snackBar - margins);
  }

  @override
  Widget build(BuildContext context) {
    final caps = WindowLayout.of(context).capsWidths;
    Widget themed(double available) => SnackBarTheme(
      data: themeFor(
        Theme.of(context).snackBarTheme,
        available: available,
        caps: caps,
      ),
      child: child,
    );
    if (_ofWindow) return themed(MediaQuery.sizeOf(context).width);
    return LayoutBuilder(
      builder: (context, constraints) => themed(constraints.maxWidth),
    );
  }
}
