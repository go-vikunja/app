import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// The server's limits for project and view titles and for identifiers,
/// counted in code points; see [CodePointLimitFormatter].
const projectTitleMaxLength = 250;
const projectIdentifierMaxLength = 10;

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

/// Says why the server refused a form whose sheet was closed while it
/// waited, where the sheet would have shown it.
void showFailureAfterClose(ScaffoldMessengerState messenger, String text) =>
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

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

class ParentProjectTile extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final String label;

  /// Null while the form is being saved.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      enabled: onTap != null,
      leading: Icon(Icons.folder_outlined, color: colors.onSurfaceVariant),
      title: Text(l10n.projectParentLabel),
      subtitle: Text(label),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: onTap,
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
