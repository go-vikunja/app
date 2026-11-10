import 'package:flutter/widgets.dart';

/// The Material 3 window width classes the app tells apart.
enum WindowSizeClass { compact, medium, expanded }

/// The window's size classes, from the logical window size: every window
/// threshold of the app lives here. A widget that sizes itself reads its own
/// constraints instead.
@immutable
final class WindowLayout {
  const new(this.size);

  factory of(BuildContext context) => WindowLayout(MediaQuery.sizeOf(context));

  static const mediumWidthFrom = 600.0;
  static const expandedWidthFrom = 840.0;
  static const mediumHeightFrom = 480.0;
  static const expandedHeightFrom = 900.0;

  /// Material 3's navigation rail. The shell's own grows with long labels
  /// and large text; [threePane] leaves that out on purpose.
  static const railWidth = 80.0;

  /// Material 3's large windows (1,200 dp) less [railWidth].
  static const threePaneContentFrom = 1120.0;

  final Size size;

  WindowSizeClass get sizeClass => switch (size.width) {
    < mediumWidthFrom => WindowSizeClass.compact,
    < expandedWidthFrom => WindowSizeClass.medium,
    _ => WindowSizeClass.expanded,
  };

  /// A phone in landscape: too low for panes or for side margins.
  bool get compactHeight => size.height < mediumHeightFrom;

  bool get expandedHeight => size.height >= expandedHeightFrom;

  /// Room for a pane beside the content.
  bool get twoPane => size.width >= expandedWidthFrom && !compactHeight;

  /// Room for a column on the start side as well as the pane: [twoPane]
  /// with [threePaneContentFrom] beside a rail of [railWidth], if
  /// [besideRail]. It comes from the window alone, so the rail's labels
  /// in another language or at a larger text size cannot change it.
  bool threePane({required bool besideRail}) =>
      twoPane &&
      size.width - (besideRail ? railWidth : 0) >= threePaneContentFrom;

  /// Whether readable widths, the dialog cap and the iOS sheet cap apply: a
  /// tablet-sized window. Phones in either orientation and the 800×600 test
  /// surface stay as they are.
  bool get capsWidths =>
      !compactHeight && (size.width >= expandedWidthFrom || expandedHeight);
}
