import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/title_and_hint.dart';

/// The server's limits for project and view titles and for identifiers,
/// counted in code points.
const projectTitleMaxLength = 250;
const projectIdentifierMaxLength = 10;

/// Says why the server refused a form whose sheet was closed while it
/// waited, where the sheet would have shown it.
void showFailureAfterClose(ScaffoldMessengerState messenger, String text) =>
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

class ParentProjectTile extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    this.lockedNote,
    super.key,
  });

  final String label;

  /// Null while the form is being saved; not called with [lockedNote].
  final VoidCallback? onTap;

  /// Why the parent cannot be changed, under it.
  final String? lockedNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final note = lockedNote;
    return ListTile(
      enabled: onTap != null && note == null,
      leading: Icon(Icons.folder_outlined, color: colors.onSurfaceVariant),
      title: Text(l10n.projectParentLabel),
      subtitle: note == null
          ? Text(label)
          : TitleAndHint(title: label, hint: note),
      trailing: note == null ? const Icon(Icons.arrow_drop_down) : null,
      onTap: note == null ? onTap : null,
    );
  }
}
