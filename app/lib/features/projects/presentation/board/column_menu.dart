import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

enum ColumnAction {
  rename,
  limit,
  done,
  defaultColumn,
  moveLeft,
  moveRight,
  delete,
}

/// A column's options in the web's order, in groups. Move left and right
/// show only where the column can go; Delete is disabled, saying why, for
/// the last column. The done and default column change the view, which
/// needs admin rights, so they show only with [canChangeView]. While
/// [saving], a progress indicator stands in for the button.
class ColumnMenuButton extends StatelessWidget {
  const new({
    required this.bucket,
    required this.isDone,
    required this.isDefault,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.canDelete,
    required this.onSelected,
    this.canChangeView = true,
    this.saving = false,
    this.enabled = true,
    super.key,
  });

  final Bucket bucket;
  final bool isDone;
  final bool isDefault;
  final bool canMoveLeft;
  final bool canMoveRight;
  final bool canDelete;
  final ValueChanged<ColumnAction> onSelected;
  final bool canChangeView;
  final bool saving;

  /// False while another column change is on its way.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (saving) {
      return SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              semanticsLabel: l10n.boardColumnSaving,
            ),
          ),
        ),
      );
    }
    final error = Theme.of(context).colorScheme.error;
    final limit = bucket.limit;
    return PopupMenuButton<ColumnAction>(
      tooltip: l10n.boardColumnOptionsFor(bucket.title),
      enabled: enabled,
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(ColumnAction.rename, Icons.edit_outlined, l10n.boardColumnRename),
        _item(
          ColumnAction.limit,
          Icons.format_list_numbered,
          l10n.boardColumnLimit(
            limit > 0 ? '$limit' : l10n.boardColumnLimitNotSet,
          ),
        ),
        if (canChangeView) ...[
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: ColumnAction.done,
            checked: isDone,
            child: _TitleAndHint(
              title: l10n.boardDoneColumn,
              hint: l10n.boardDoneColumnHintExtended,
            ),
          ),
          CheckedPopupMenuItem(
            value: ColumnAction.defaultColumn,
            checked: isDefault,
            child: _TitleAndHint(
              title: l10n.boardDefaultColumn,
              hint: l10n.boardDefaultColumnHint,
            ),
          ),
        ],
        if (canMoveLeft || canMoveRight) const PopupMenuDivider(),
        if (canMoveLeft)
          _item(
            ColumnAction.moveLeft,
            Icons.arrow_back,
            l10n.boardColumnMoveLeft,
          ),
        if (canMoveRight)
          _item(
            ColumnAction.moveRight,
            Icons.arrow_forward,
            l10n.boardColumnMoveRight,
          ),
        const PopupMenuDivider(),
        _item(
          ColumnAction.delete,
          Icons.delete_outline,
          l10n.boardColumnDelete,
          color: canDelete ? error : null,
          enabled: canDelete,
          hint: canDelete ? null : l10n.boardColumnDeleteLast,
        ),
      ],
    );
  }

  /// Laid out like the checked items, whose check takes the icon's place.
  static PopupMenuItem<ColumnAction> _item(
    ColumnAction value,
    IconData icon,
    String label, {
    Color? color,
    bool enabled = true,
    String? hint,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: IgnorePointer(
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: color),
        title: hint == null
            ? Text(label, style: TextStyle(color: color))
            : _TitleAndHint(title: label, hint: hint),
      ),
    ),
  );
}

class _TitleAndHint extends StatelessWidget {
  const new({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 2),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
