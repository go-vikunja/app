import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';

/// The draft's assignees, each removable, and the way to the people
/// picker.
class AssigneesSection extends StatelessWidget {
  const new({
    required this.assignees,
    required this.onRemove,
    required this.onAdd,
    super.key,
  });

  final List<User> assignees;
  final ValueChanged<User> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final user in assignees)
          InputChip(
            avatar: InitialsAvatar(name: user.displayName, radius: 12),
            label: Text(
              user.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onDeleted: () => onRemove(user),
            deleteButtonTooltipMessage: l10n.taskEditUnassign(user.displayName),
          ),
        ActionChip(
          avatar: Icon(
            Icons.person_add_alt_outlined,
            color: colors.onSurfaceVariant,
          ),
          label: Text(l10n.taskEditAssign),
          onPressed: onAdd,
        ),
      ],
    );
  }
}
