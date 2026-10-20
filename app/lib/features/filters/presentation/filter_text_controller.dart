import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/filters/application/filter_syntax.dart';

/// Shows a filter's parts the way the web's filter input does: fields,
/// operators, values and joins each in their own colour and weight or
/// underline, so colour is never the only cue; a word in a field's place
/// that names no field gets a wavy underline. No part gets a background,
/// which would be painted over the selection and, on Android, the caret.
/// Not [highlighted], as while the field is disabled, the text is plain.
class FilterTextEditingController extends TextEditingController {
  new({super.text});

  bool highlighted = true;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final spans = highlighted ? filterSpans(text) : const <FilterSpan>[];
    if (spans.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final boundaries = <int>{
      0,
      text.length,
      for (final span in spans) ...[span.start, span.end],
      if (!composing.isCollapsed) ...[composing.start, composing.end],
    }.toList()..sort();
    final styles = _FilterStyles(Theme.of(context).colorScheme);
    final children = <TextSpan>[];
    var spanIndex = 0;
    for (var i = 0; i + 1 < boundaries.length; i++) {
      final from = boundaries[i];
      final to = boundaries[i + 1];
      while (spanIndex < spans.length && spans[spanIndex].end <= from) {
        spanIndex++;
      }
      final span = spanIndex < spans.length && spans[spanIndex].start <= from
          ? spans[spanIndex]
          : null;
      var segmentStyle = span == null ? null : styles.of(span.kind);
      if (!composing.isCollapsed &&
          from >= composing.start &&
          to <= composing.end) {
        segmentStyle = (segmentStyle ?? const TextStyle()).copyWith(
          decoration: TextDecoration.combine([
            ?segmentStyle?.decoration,
            TextDecoration.underline,
          ]),
        );
      }
      children.add(
        TextSpan(text: text.substring(from, to), style: segmentStyle),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

final class _FilterStyles {
  const new(this._colors);

  final ColorScheme _colors;

  TextStyle of(FilterSpanKind kind) => switch (kind) {
    FilterSpanKind.field => TextStyle(
      color: _colors.primary,
      fontWeight: FontWeight.w700,
    ),
    FilterSpanKind.unknownField => TextStyle(
      color: _colors.error,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: _colors.error,
    ),
    FilterSpanKind.operator => TextStyle(
      color: _colors.tertiary,
      fontWeight: FontWeight.w700,
    ),
    FilterSpanKind.value => TextStyle(
      color: _colors.secondary,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: _colors.secondary,
    ),
    FilterSpanKind.join => TextStyle(
      color: _colors.onSurface,
      fontWeight: FontWeight.w900,
      decoration: TextDecoration.underline,
      decorationColor: _colors.outline,
    ),
  };
}
