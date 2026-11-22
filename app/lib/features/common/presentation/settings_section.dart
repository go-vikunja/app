import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/section_semantics.dart';

/// A group of a settings list, drawn like a [SectionCard]: the header in
/// the primary colour, then one rounded card with its tiles (`ListTile`s
/// with a 24 dp outlined leading icon) and inset dividers between them.
/// A tile may build nothing, such as a note shown only in some states;
/// the card then draws no divider for it.
class SettingsSection extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SectionSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListSectionHeader(
            title: title,
            trailing: trailing,
            padding: SectionCard.headerPadding,
          ),
          Padding(
            padding: SectionCard.defaultMargin,
            child: Material(
              color: colors.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(SectionCardItem.radius),
              ),
              child: _DividedRows(
                dividerColor: sectionCardDividerColor(colors),
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows one below the other at the full width, with a divider between
/// each two that take up space.
class _DividedRows extends MultiChildRenderObjectWidget {
  const new({required this.dividerColor, required super.children});

  final Color dividerColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDividedRows(dividerColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDividedRows renderObject,
  ) => renderObject.dividerColor = dividerColor;
}

class _RowParentData extends ContainerBoxParentData<RenderBox>;

class _RenderDividedRows extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  new(this._dividerColor);

  static const _dividerHeight = 1.0;
  static const _dividerInset = 16.0;

  Color _dividerColor;
  Color get dividerColor => _dividerColor;
  set dividerColor(Color value) {
    if (value == _dividerColor) return;
    _dividerColor = value;
    markNeedsPaint();
  }

  final _dividerTops = <double>[];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  BoxConstraints _rowConstraints(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? BoxConstraints.tightFor(width: constraints.maxWidth)
      : const BoxConstraints();

  /// The total height of rows of [heights], with a divider before every
  /// row that has a height and follows another one that has.
  static double _stackedHeight(
    Iterable<double> heights, [
    void Function(double rowTop, double? dividerTop)? place,
  ]) {
    var top = 0.0;
    var anyShown = false;
    for (final height in heights) {
      double? dividerTop;
      if (height > 0) {
        if (anyShown) {
          dividerTop = top;
          top += _dividerHeight;
        }
        anyShown = true;
      }
      place?.call(top, dividerTop);
      top += height;
    }
    return top;
  }

  Iterable<RenderBox> get _rows sync* {
    var child = firstChild;
    while (child != null) {
      yield child;
      child = childAfter(child);
    }
  }

  @override
  void performLayout() {
    final rowConstraints = _rowConstraints(constraints);
    final rows = _rows.toList();
    for (final row in rows) {
      row.layout(rowConstraints, parentUsesSize: true);
    }
    _dividerTops.clear();
    var index = 0;
    final height = _stackedHeight(rows.map((row) => row.size.height), (
      rowTop,
      dividerTop,
    ) {
      if (dividerTop != null) _dividerTops.add(dividerTop);
      (rows[index++].parentData! as _RowParentData).offset = Offset(0, rowTop);
    });
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : rows.fold<double>(
            0,
            (widest, row) => math.max(widest, row.size.width),
          );
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final rowConstraints = _rowConstraints(constraints);
    final sizes = [for (final row in _rows) row.getDryLayout(rowConstraints)];
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : sizes.fold<double>(0, (widest, size) => math.max(widest, size.width));
    return constraints.constrain(
      Size(width, _stackedHeight(sizes.map((size) => size.height))),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _rows.fold(
    0,
    (widest, row) => math.max(widest, row.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _rows.fold(
    0,
    (widest, row) => math.max(widest, row.getMaxIntrinsicWidth(height)),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _stackedHeight(_rows.map((row) => row.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _stackedHeight(_rows.map((row) => row.getMaxIntrinsicHeight(width)));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    if (_dividerTops.isEmpty || size.width <= 2 * _dividerInset) return;
    final paint = Paint()..color = _dividerColor;
    for (final top in _dividerTops) {
      context.canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + _dividerInset,
          offset.dy + top,
          size.width - 2 * _dividerInset,
          _dividerHeight,
        ),
        paint,
      );
    }
  }
}
