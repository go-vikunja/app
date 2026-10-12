import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';

typedef MagicHighlighter = List<MagicSpan> Function(String text);

/// Colours of the recognised parts, shared by the field and the preview
/// chips so that each chip matches its part of the text.
abstract final class MagicColors {
  static const Map<MagicSpanKind, Color> _seeds = {
    MagicSpanKind.label: Color(0xFF8338EC),
    MagicSpanKind.project: Color(0xFF0EAD69),
    MagicSpanKind.priority: Color(0xFFFB5607),
    MagicSpanKind.assignee: Color(0xFFFF006E),
    MagicSpanKind.date: Color(0xFF1973FF),
    MagicSpanKind.repeat: Color(0xFF00A3A3),
  };

  static final Map<(Brightness, MagicSpanKind), ColorScheme> _schemes = {};

  /// The text colour and background of [kind]'s highlight.
  static (Color, Color) of(BuildContext context, MagicSpanKind kind) {
    final theme = Theme.of(context);
    if (kind == MagicSpanKind.unmatchedProject) {
      final colors = theme.colorScheme;
      return (colors.onErrorContainer, colors.errorContainer);
    }
    final scheme = _schemes.putIfAbsent(
      (theme.brightness, kind),
      () => ColorScheme.fromSeed(
        seedColor: _seeds[kind]!,
        brightness: theme.brightness,
      ),
    );
    return (scheme.onPrimaryContainer, scheme.primaryContainer);
  }

  /// For icons on the surface.
  static Color accentOf(BuildContext context, MagicSpanKind kind) {
    final theme = Theme.of(context);
    if (kind == MagicSpanKind.unmatchedProject) return theme.colorScheme.error;
    return _schemes.putIfAbsent(
      (theme.brightness, kind),
      () => ColorScheme.fromSeed(
        seedColor: _seeds[kind]!,
        brightness: theme.brightness,
      ),
    ).primary;
  }
}

/// Shows what Quick Add Magic recognised: each part in its colour, on a
/// tinted background and in a heavier weight, so colour is never the only
/// cue. An unmatched project gets a wavy underline.
class MagicTextEditingController extends TextEditingController {
  new({super.text});

  /// Null shows plain text.
  MagicHighlighter? highlighter;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final spans = highlighter?.call(text) ?? const <MagicSpan>[];
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
      for (final span in spans) ...[
        span.start.clamp(0, text.length),
        span.end.clamp(0, text.length),
      ],
      if (!composing.isCollapsed) ...[composing.start, composing.end],
    }.toList()..sort();

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
      var segmentStyle = span == null ? null : _styleOf(context, span.kind);
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

  TextStyle _styleOf(BuildContext context, MagicSpanKind kind) {
    final (foreground, background) = MagicColors.of(context, kind);
    final unmatched = kind == MagicSpanKind.unmatchedProject;
    return TextStyle(
      color: foreground,
      backgroundColor: background,
      fontWeight: FontWeight.w700,
      decoration: unmatched ? TextDecoration.underline : null,
      decorationStyle: unmatched ? TextDecorationStyle.wavy : null,
      decorationColor: unmatched ? Theme.of(context).colorScheme.error : null,
    );
  }
}
