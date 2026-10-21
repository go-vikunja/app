import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

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
