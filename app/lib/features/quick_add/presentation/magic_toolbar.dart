import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// Assist chips above the keyboard that type the mode's prefixes, a
/// priority menu and the way to the syntax help.
class MagicToolbar extends StatelessWidget {
  const new({
    required this.prefixes,
    required this.onInsertPrefix,
    required this.onPriority,
    required this.onHelp,
    super.key,
  });

  final QuickAddPrefixes prefixes;
  final ValueChanged<String> onInsertPrefix;
  final ValueChanged<int> onPriority;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
              child: Row(
                spacing: 8,
                children: [
                  _PrefixButton(
                    kind: MagicSpanKind.label,
                    icon: Icons.label_outline,
                    prefix: prefixes.label,
                    tooltip: l10n.quickAddInsertLabel(prefixes.label),
                    onPressed: () => onInsertPrefix(prefixes.label),
                  ),
                  _PrefixButton(
                    kind: MagicSpanKind.project,
                    icon: Icons.folder_outlined,
                    prefix: prefixes.project,
                    tooltip: l10n.quickAddInsertProject(prefixes.project),
                    onPressed: () => onInsertPrefix(prefixes.project),
                  ),
                  _PrefixButton(
                    kind: MagicSpanKind.assignee,
                    icon: Icons.person_add_alt,
                    prefix: prefixes.assignee,
                    tooltip: l10n.quickAddInsertAssignee(prefixes.assignee),
                    onPressed: () => onInsertPrefix(prefixes.assignee),
                  ),
                  MenuAnchor(
                    menuChildren: [
                      for (final priority in [
                        TaskPriority.low,
                        TaskPriority.medium,
                        TaskPriority.high,
                        TaskPriority.urgent,
                        TaskPriority.doNow,
                      ])
                        MenuItemButton(
                          trailingIcon: Text(
                            '${prefixes.priority}${priority.value}',
                          ),
                          onPressed: () => onPriority(priority.value),
                          child: Text(priorityLabel(l10n, priority)),
                        ),
                    ],
                    builder: (context, controller, _) => _PrefixButton(
                      kind: MagicSpanKind.priority,
                      icon: Icons.flag_outlined,
                      prefix: prefixes.priority,
                      tooltip: l10n.quickAddSetPriority(prefixes.priority),
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.quickAddHelp,
            onPressed: onHelp,
          ),
        ],
      ),
    );
  }
}

class _PrefixButton extends StatelessWidget {
  const new({
    required this.kind,
    required this.icon,
    required this.prefix,
    required this.tooltip,
    required this.onPressed,
  });

  final MagicSpanKind kind;
  final IconData icon;
  final String prefix;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, color: MagicColors.accentOf(context, kind)),
    // The tooltip names the chip; the prefix only shows what it types.
    label: ExcludeSemantics(
      child: Text(
        prefix,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
