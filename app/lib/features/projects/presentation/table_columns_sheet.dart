import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

String tableColumnLabel(AppLocalizations l10n, TableColumn column) =>
    switch (column) {
      TableColumn.taskIndex => l10n.projectTableColumnNumber,
      TableColumn.done => l10n.taskDone,
      TableColumn.project => l10n.taskEditProject,
      TableColumn.title => l10n.taskEditTitleLabel,
      TableColumn.priority => l10n.taskDetailPriority,
      TableColumn.labels => l10n.taskDetailLabels,
      TableColumn.assignees => l10n.taskDetailAssignees,
      TableColumn.commentCount => l10n.projectTableColumnComments,
      TableColumn.dueDate => l10n.taskDetailDueDate,
      TableColumn.startDate => l10n.taskDetailStartDate,
      TableColumn.endDate => l10n.taskDetailEndDate,
      TableColumn.percentDone => l10n.taskDetailProgress,
      TableColumn.doneAt => l10n.projectTableColumnDoneAt,
      TableColumn.created => l10n.projectTableColumnCreated,
      TableColumn.updated => l10n.projectTableColumnUpdated,
      TableColumn.createdBy => l10n.projectTableColumnCreatedBy,
    };

/// The web table's columns as checkboxes in its order, each with the icon
/// its value has in a row; every change goes to [onChanged] at once, so
/// the table behind follows. The title stays on: every row shows it.
Future<void> showTableColumnsSheet(
  BuildContext context, {
  required Set<TableColumn> columns,
  required ValueChanged<Set<TableColumn>> onChanged,
}) => showPickerSheet<void>(
  context,
  builder: (context, scrollController) => _TableColumnsSheet(
    initial: columns,
    onChanged: onChanged,
    scrollController: scrollController,
  ),
);

class _TableColumnsSheet extends StatefulWidget {
  const new({
    required this.initial,
    required this.onChanged,
    required this.scrollController,
  });

  final Set<TableColumn> initial;
  final ValueChanged<Set<TableColumn>> onChanged;
  final ScrollController? scrollController;

  @override
  State<_TableColumnsSheet> createState() => _TableColumnsSheetState();
}

class _TableColumnsSheetState extends State<_TableColumnsSheet> {
  late Set<TableColumn> _columns = {...widget.initial, TableColumn.title};

  void _set(Set<TableColumn> columns) {
    setState(() => _columns = columns);
    widget.onChanged(columns);
  }

  void _toggle(TableColumn column, {required bool on}) =>
      _set(on ? {..._columns, column} : ({..._columns}..remove(column)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDefault =
        _columns.length == TableColumn.defaults.length &&
        _columns.containsAll(TableColumn.defaults);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(
          title: l10n.projectTableColumns,
          actionLabel: l10n.projectTableColumnsReset,
          onAction: isDefault ? null : () => _set(TableColumn.defaults),
        ),
        Flexible(
          child: ListView(
            controller: widget.scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.projectTableColumnsHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final column in TableColumn.values)
                CheckboxListTile.adaptive(
                  value: _columns.contains(column),
                  onChanged: column == TableColumn.title
                      ? null
                      : (on) => _toggle(column, on: on ?? false),
                  secondary: Icon(
                    tableColumnIcon(column),
                    color: colors.onSurfaceVariant,
                  ),
                  title: Text(tableColumnLabel(l10n, column)),
                  subtitle: column == TableColumn.title
                      ? Text(l10n.projectTableColumnTitleAlways)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
