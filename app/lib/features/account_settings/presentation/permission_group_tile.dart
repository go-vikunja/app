import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_permissions.dart';

/// A group of a token's permissions: a checkbox for the whole group that is
/// mixed while only some are picked, the count picked, and the group's own
/// checkboxes below it once expanded. Ticking the group picks all of them,
/// unticking a full group clears it. Names stay as the server sends them,
/// made readable but untranslated, like on the web.
class PermissionGroupTile extends StatelessWidget {
  const new({
    required this.group,
    required this.permissions,
    required this.selected,
    required this.expanded,
    required this.enabled,
    required this.onGroupChanged,
    required this.onPermissionChanged,
    required this.onExpandedChanged,
    super.key,
  });

  final String group;
  final List<String> permissions;
  final Set<String> selected;
  final bool expanded;
  final bool enabled;

  /// True to pick every permission of the group, false to clear it.
  final ValueChanged<bool> onGroupChanged;
  final void Function(String permission, {required bool selected})
  onPermissionChanged;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = permissions.where(selected.contains).length;
    final all = picked == permissions.length && picked > 0;
    final name = humanizePermission(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: CheckboxListTile.adaptive(
                tristate: true,
                value: all ? true : (picked == 0 ? false : null),
                controlAffinity: ListTileControlAffinity.leading,
                enabled: enabled,
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.apiTokenFormGroupSelected(picked, permissions.length),
                ),
                onChanged: (_) => onGroupChanged(!all),
              ),
            ),
            IconButton(
              onPressed: () => onExpandedChanged(!expanded),
              tooltip: expanded
                  ? l10n.apiTokenFormHideGroup(name)
                  : l10n.apiTokenFormShowGroup(name),
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (expanded)
          for (final permission in permissions)
            CheckboxListTile.adaptive(
              value: selected.contains(permission),
              controlAffinity: ListTileControlAffinity.leading,
              enabled: enabled,
              contentPadding: const EdgeInsetsDirectional.only(
                start: 48,
                end: 16,
              ),
              title: Text(humanizePermission(permission)),
              onChanged: (value) =>
                  onPermissionChanged(permission, selected: value ?? false),
            ),
      ],
    );
  }
}
