import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// The project new tasks go to, as an outlined field with the project's
/// colour that opens the picker; disabled without [onPressed], e.g. while
/// the text names the project, which [leading] can show.
class ProjectField extends StatelessWidget {
  const new({
    required this.title,
    required this.onPressed,
    this.color,
    this.leading,
    super.key,
  });

  final String title;
  final VoidCallback? onPressed;
  final Color? color;

  /// In place of the colour dot.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = this.color;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.taskEditProjectSemantics(title),
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.taskEditProject,
            enabled: enabled,
            prefixIcon:
                leading ??
                (color == null
                    ? const Icon(Icons.folder_outlined)
                    : Center(widthFactor: 1, child: ColorDot(color: color))),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(title),
        ),
      ),
    );
  }
}
