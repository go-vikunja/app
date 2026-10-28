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

  /// Whether readable widths, the dialog cap and the iOS sheet cap apply: a
  /// tablet-sized window. Phones in either orientation and the 800×600 test
  /// surface stay as they are.
  bool get capsWidths =>
      !compactHeight && (size.width >= expandedWidthFrom || expandedHeight);
}
