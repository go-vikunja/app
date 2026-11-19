import 'package:flutter/widgets.dart';

/// [style] as [Text] draws it: bold under the platform's Bold Text, so that
/// a [TextPainter] measures what is drawn.
TextStyle drawnTextStyle(BuildContext context, TextStyle style) =>
    MediaQuery.boldTextOf(context)
    ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
    : style;
