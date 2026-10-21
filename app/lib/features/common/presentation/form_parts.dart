import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps a field within [maxLength] code points, as the server counts.
/// Flutter's `LengthLimitingTextInputFormatter` counts characters as shown,
/// and one emoji can be several code points. A text already over the limit,
/// such as a stored title, can still be shortened.
final class CodePointLimitFormatter extends TextInputFormatter {
  new(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final length = newValue.text.runes.length;
    if (length <= maxLength) return newValue;
    final oldLength = oldValue.text.runes.length;
    if (length < oldLength) return newValue;
    if (oldLength >= maxLength && oldValue.selection.isCollapsed) {
      return oldValue;
    }
    final text = String.fromCharCodes(newValue.text.runes.take(maxLength));
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: math.min(newValue.selection.baseOffset, text.length),
        extentOffset: math.min(newValue.selection.extentOffset, text.length),
      ),
    );
  }
}

class FormSectionTitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Why the server refused a form, announced as it appears.
class FormErrorText extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
