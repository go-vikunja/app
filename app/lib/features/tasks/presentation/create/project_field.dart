import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';

/// The project new tasks go to, as an outlined field with the project's
/// coloured folder that opens the picker; disabled without [onPressed],
/// e.g. while the text names the project, which [note] can say.
class ProjectField extends StatelessWidget {
  const new({
    required this.title,
    required this.onPressed,
    this.hexColor = '',
    this.note,
    super.key,
  });

  final String title;
  final VoidCallback? onPressed;
  final String hexColor;

  /// In place of the picker's arrow, which a field with a note has no use
  /// for.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final note = this.note;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.taskEditProjectSemantics(title),
      hint: note,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.taskEditProject,
            enabled: enabled,
            prefixIcon: ProjectIcon(hexColor: hexColor),
            suffixIcon: note == null ? const Icon(Icons.arrow_drop_down) : null,
            suffix: note == null
                ? null
                : Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          child: Text(title),
        ),
      ),
    );
  }
}
