import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

typedef ReadableWidthBuilder = Widget Function(
  BuildContext context,
  double contentWidth,
  double inset,
);

/// Centres [child] in at most [maxWidth] of the available width by equal
/// side insets, on large windows only ([WindowLayout.capsWidths]). It always
/// stays in the tree, with no inset otherwise, so a resize keeps the
/// child's state.
///
/// Around a scroll view, use [ReadableWidth.builder] and put the inset into
/// the scroll view's padding (or [SliverReadableWidth] into its slivers), so
/// the margins scroll and the scrollbar stays at the edge.
class ReadableWidth extends StatelessWidget {
  const new({required this.maxWidth, required Widget this.child, super.key})
    : builder = null;

  const new builder({
    required this.maxWidth,
    required ReadableWidthBuilder this.builder,
    super.key,
  }) : child = null;

  /// Task lists, the overview and the project tree.
  static const list = 840.0;

  /// Settings, forms and detail pages.
  static const form = 640.0;

  /// The content of an iOS sheet.
  static const sheet = 640.0;

  /// Material dialogs (M3).
  static const dialog = 560.0;

  /// Flutter's own bounds for a dialog's width, which the date and time
  /// pickers keep under the [dialog] cap.
  static const defaultDialogConstraints = BoxConstraints(minWidth: 280);

  static double insetFor({
    required double available,
    required double max,
    required bool caps,
  }) => caps && available.isFinite ? math.max(0, (available - max) / 2) : 0;

  final double maxWidth;
  final Widget? child;
  final ReadableWidthBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final caps = WindowLayout.of(context).capsWidths;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = insetFor(
          available: constraints.maxWidth,
          max: maxWidth,
          caps: caps,
        );
        if (builder case final builder?) {
          return builder(context, constraints.maxWidth - 2 * inset, inset);
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: child,
        );
      },
    );
  }
}

/// [ReadableWidth] for the slivers of a `CustomScrollView`: [sliver], or
/// [slivers] as one group, inset to at most [maxWidth] of the cross axis.
class SliverReadableWidth extends StatelessWidget {
  const new({required this.maxWidth, required Widget this.sliver, super.key})
    : slivers = null;

  const new group({
    required this.maxWidth,
    required List<Widget> this.slivers,
    super.key,
  }) : sliver = null;

  final double maxWidth;
  final Widget? sliver;
  final List<Widget>? slivers;

  @override
  Widget build(BuildContext context) {
    final caps = WindowLayout.of(context).capsWidths;
    final content = sliver ?? SliverMainAxisGroup(slivers: slivers!);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: ReadableWidth.insetFor(
            available: constraints.crossAxisExtent,
            max: maxWidth,
            caps: caps,
          ),
        ),
        sliver: content,
      ),
    );
  }
}
