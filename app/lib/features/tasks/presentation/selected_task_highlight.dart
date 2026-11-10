import 'package:material_ui/material_ui.dart';

/// Marks the row or card of the task open in the pane beside the list: a
/// tint, and an indicator in the primary colour, as the tint alone stands
/// out too little from the cards. Painted on the nearest [Material], under
/// the ink of [child], and laid out the same either way; always in the
/// tree, so a change of the selection keeps [child]'s state. It also marks
/// the rows of the project or list open beside the project tree's column.
class SelectedTaskHighlight extends StatelessWidget {
  const new({
    required this.selected,
    required this.child,
    this.cardRadius,
    super.key,
  });

  final bool selected;
  final Widget child;

  /// A card's corner radius: the indicator then outlines the card. Null
  /// for a row, which gets a bar along its start edge.
  final Radius? cardRadius;

  static const rowIndicatorWidth = 4.0;
  static const outlineWidth = 2.0;

  static Color fillOf(ColorScheme colors) => colors.surfaceContainerHighest;

  static Color indicatorOf(ColorScheme colors) => colors.primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Ink(
      decoration: selected
          ? SelectedTaskDecoration(
              fill: fillOf(colors),
              indicator: indicatorOf(colors),
              cardRadius: cardRadius,
            )
          : null,
      child: child,
    );
  }
}

/// [SelectedTaskHighlight]'s look. Unlike a [BoxDecoration] with a border,
/// it takes no padding, so the selected row's content stays in place.
final class SelectedTaskDecoration extends Decoration {
  const new({required this.fill, required this.indicator, this.cardRadius});

  final Color fill;
  final Color indicator;
  final Radius? cardRadius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _SelectedTaskPainter(this);

  @override
  bool operator ==(Object other) =>
      other is SelectedTaskDecoration &&
      other.fill == fill &&
      other.indicator == indicator &&
      other.cardRadius == cardRadius;

  @override
  int get hashCode => Object.hash(fill, indicator, cardRadius);
}

class _SelectedTaskPainter extends BoxPainter {
  new(this._decoration);

  final SelectedTaskDecoration _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    final fill = Paint()..color = _decoration.fill;
    final indicator = Paint()..color = _decoration.indicator;
    if (_decoration.cardRadius case final radius?) {
      const inset = SelectedTaskHighlight.outlineWidth / 2;
      canvas
        ..drawRRect(RRect.fromRectAndRadius(rect, radius), fill)
        ..drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(inset),
            (radius - const Radius.circular(inset)).clamp(minimum: Radius.zero),
          ),
          indicator
            ..style = PaintingStyle.stroke
            ..strokeWidth = SelectedTaskHighlight.outlineWidth,
        );
      return;
    }
    const width = SelectedTaskHighlight.rowIndicatorWidth;
    final start = configuration.textDirection == TextDirection.rtl
        ? rect.right - width
        : rect.left;
    canvas
      ..drawRect(rect, fill)
      ..drawRect(Rect.fromLTWH(start, rect.top, width, rect.height), indicator);
  }
}
