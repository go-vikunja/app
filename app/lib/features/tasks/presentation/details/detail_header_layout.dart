import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

enum DetailHeaderSlot { back, breadcrumb, actions }

/// The detail's header: [back] at the start of its line and [actions] at
/// the end, [breadcrumb] between them when it fits there whole, else on a
/// line of its own below them, [breadcrumbIndent] in from the start.
class DetailHeaderLayout
    extends SlottedMultiChildRenderObjectWidget<DetailHeaderSlot, RenderBox> {
  const new({
    required this.actions,
    this.back,
    this.breadcrumb,
    this.breadcrumbIndent = 0,
    super.key,
  });

  final Widget? back;
  final Widget? breadcrumb;
  final Widget actions;
  final double breadcrumbIndent;

  @override
  Iterable<DetailHeaderSlot> get slots => DetailHeaderSlot.values;

  @override
  Widget? childForSlot(DetailHeaderSlot slot) => switch (slot) {
    DetailHeaderSlot.back => back,
    DetailHeaderSlot.breadcrumb => breadcrumb,
    DetailHeaderSlot.actions => actions,
  };

  @override
  RenderDetailHeader createRenderObject(BuildContext context) =>
      RenderDetailHeader(
        textDirection: Directionality.of(context),
        breadcrumbIndent: breadcrumbIndent,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDetailHeader renderObject,
  ) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..breadcrumbIndent = breadcrumbIndent;
  }
}

typedef _HeaderLayout = ({
  Size size,
  Offset back,
  Offset breadcrumb,
  Offset actions,
});

class RenderDetailHeader extends RenderBox
    with SlottedContainerRenderObjectMixin<DetailHeaderSlot, RenderBox> {
  new({required this._textDirection, required this._breadcrumbIndent});

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double get breadcrumbIndent => _breadcrumbIndent;
  double _breadcrumbIndent;
  set breadcrumbIndent(double value) {
    if (value == _breadcrumbIndent) return;
    _breadcrumbIndent = value;
    markNeedsLayout();
  }

  RenderBox? get _back => childForSlot(DetailHeaderSlot.back);
  RenderBox? get _breadcrumb => childForSlot(DetailHeaderSlot.breadcrumb);
  RenderBox? get _actions => childForSlot(DetailHeaderSlot.actions);

  double _width(RenderBox? child) =>
      child?.getMaxIntrinsicWidth(double.infinity) ?? 0;

  bool _fitsInLine(double width) =>
      _width(_back) + _width(_breadcrumb) + _width(_actions) <= width;

  _HeaderLayout _layout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final back = _back;
    final breadcrumb = _breadcrumb;
    final actions = _actions;
    final loose = constraints.loosen();
    final backSize = back == null ? Size.zero : layoutChild(back, loose);
    final actionsSize = actions == null
        ? Size.zero
        : layoutChild(actions, loose);
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : backSize.width + _width(breadcrumb) + actionsSize.width;
    final lineHeight = math.max(backSize.height, actionsSize.height);
    final inLine = _fitsInLine(width);
    final room = inLine
        ? width - backSize.width - actionsSize.width
        : width - breadcrumbIndent;
    final breadcrumbSize = breadcrumb == null
        ? Size.zero
        : layoutChild(breadcrumb, BoxConstraints(maxWidth: math.max(0, room)));
    final height = inLine
        ? math.max(lineHeight, breadcrumbSize.height)
        : lineHeight + breadcrumbSize.height;
    final firstLine = inLine ? height : lineHeight;
    Offset at(double start, Size child, double top) => Offset(
      textDirection == TextDirection.ltr ? start : width - start - child.width,
      top,
    );
    return (
      size: constraints.constrain(Size(width, height)),
      back: at(0, backSize, (firstLine - backSize.height) / 2),
      breadcrumb: inLine
          ? at(
              backSize.width,
              breadcrumbSize,
              (height - breadcrumbSize.height) / 2,
            )
          : at(breadcrumbIndent, breadcrumbSize, lineHeight),
      actions: at(
        width - actionsSize.width,
        actionsSize,
        (firstLine - actionsSize.height) / 2,
      ),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final layout = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = layout.size;
    for (final (child, offset) in [
      (_back, layout.back),
      (_breadcrumb, layout.breadcrumb),
      (_actions, layout.actions),
    ]) {
      if (child != null) (child.parentData! as BoxParentData).offset = offset;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _width(_back) + _width(_actions),
    (_breadcrumb?.getMinIntrinsicWidth(height) ?? 0) + breadcrumbIndent,
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _width(_back) + _width(_breadcrumb) + _width(_actions);

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final back = _back;
    final breadcrumb = _breadcrumb;
    final actions = _actions;
    final lineHeight = math.max(
      back == null ? 0.0 : heightOf(back, double.infinity),
      actions == null ? 0.0 : heightOf(actions, double.infinity),
    );
    if (breadcrumb == null) return lineHeight;
    if (_fitsInLine(width)) {
      return math.max(
        lineHeight,
        heightOf(breadcrumb, width - _width(back) - _width(actions)),
      );
    }
    return lineHeight +
        heightOf(breadcrumb, math.max(0, width - breadcrumbIndent));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
