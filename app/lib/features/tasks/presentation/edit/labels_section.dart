import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';

/// The draft's labels in their colours, each removable, and the way to the
/// label picker.
class LabelsSection extends StatelessWidget {
  const new({
    required this.labels,
    required this.onRemove,
    required this.onAdd,
    super.key,
  });

  final List<Label> labels;
  final ValueChanged<Label> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels) _RemovableLabelChip(label, onRemove),
        ActionChip(
          avatar: Icon(Icons.add, color: colors.onSurfaceVariant),
          label: Text(l10n.taskEditAddLabel),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _RemovableLabelChip extends StatelessWidget {
  const new(this.label, this.onRemove);

  final Label label;
  final ValueChanged<Label> onRemove;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(label.hexColor);
    final foreground = color == null ? null : contrastingTextColor(color);
    return InputChip(
      label: Text(label.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      labelStyle: foreground == null ? null : TextStyle(color: foreground),
      backgroundColor: color,
      side: color == null ? null : BorderSide(color: color),
      deleteIconColor: foreground,
      onDeleted: () => onRemove(label),
      deleteButtonTooltipMessage: context.l10n.taskEditRemoveLabel(label.title),
    );
  }
}
