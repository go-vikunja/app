import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_source_items.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';

enum _TableAction {
  insert,
  addRow,
  addColumn,
  deleteRow,
  deleteColumn,
  deleteTable,
}

/// Every formatting command of the editor as native buttons above the
/// keyboard, each showing whether it applies at the cursor. The web has no
/// highlight mark, so there is no button for it. The image button shows
/// only with [onImage], which gets where to take the image from, and takes
/// taps while [imageEnabled].
class EditorToolbar extends StatelessWidget {
  const new({
    required this.state,
    required this.enabled,
    required this.onCommand,
    required this.onLink,
    this.onImage,
    this.imageEnabled = true,
    super.key,
  });

  final EditorState state;
  final bool enabled;
  final ValueChanged<EditorCommand> onCommand;
  final VoidCallback onLink;
  final ValueChanged<AttachmentSource>? onImage;
  final bool imageEnabled;

  /// The height the toolbar takes in [context]: one row of buttons and the
  /// bottom safe area.
  static double heightOf(BuildContext context) =>
      kMinInteractiveDimension +
      2 * _padding +
      MediaQuery.paddingOf(context).bottom;

  static const _padding = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final active = state.active;

    Widget toggle(
      IconData icon,
      String label,
      EditorCommandName command, {
      required bool on,
    }) => _ToggleButton(
      icon: icon,
      label: label,
      active: on,
      onPressed: enabled ? () => onCommand(EditorCommand(command)) : null,
    );

    Widget action(
      IconData icon,
      String label,
      EditorCommandName command, {
      bool available = true,
    }) => IconButton(
      onPressed: enabled && available
          ? () => onCommand(EditorCommand(command))
          : null,
      tooltip: label,
      icon: Icon(icon),
    );

    final groups = <List<Widget>>[
      [
        toggle(
          Icons.format_bold,
          l10n.editorBold,
          EditorCommandName.bold,
          on: active.bold,
        ),
        toggle(
          Icons.format_italic,
          l10n.editorItalic,
          EditorCommandName.italic,
          on: active.italic,
        ),
        toggle(
          Icons.format_underlined,
          l10n.editorUnderline,
          EditorCommandName.underline,
          on: active.underline,
        ),
        toggle(
          Icons.format_strikethrough,
          l10n.editorStrike,
          EditorCommandName.strike,
          on: active.strike,
        ),
        toggle(
          Icons.code,
          l10n.editorCode,
          EditorCommandName.code,
          on: active.code,
        ),
      ],
      [
        _HeadingMenu(
          level: active.heading,
          enabled: enabled,
          onSelected: (level) => onCommand(EditorCommand.heading(level)),
        ),
        toggle(
          Icons.format_list_bulleted,
          l10n.editorBulletList,
          EditorCommandName.bulletList,
          on: active.bulletList,
        ),
        toggle(
          Icons.format_list_numbered,
          l10n.editorOrderedList,
          EditorCommandName.orderedList,
          on: active.orderedList,
        ),
        toggle(
          Icons.checklist,
          l10n.editorTaskList,
          EditorCommandName.taskList,
          on: active.taskList,
        ),
        toggle(
          Icons.format_quote,
          l10n.editorQuote,
          EditorCommandName.blockquote,
          on: active.blockquote,
        ),
        toggle(
          Icons.data_object,
          l10n.editorCodeBlock,
          EditorCommandName.codeBlock,
          on: active.codeBlock,
        ),
      ],
      [
        _ToggleButton(
          icon: Icons.link,
          label: l10n.editorLink,
          active: active.link,
          onPressed: enabled ? onLink : null,
        ),
        if (onImage case final onImage?)
          _ImageMenu(enabled: enabled && imageEnabled, onSelected: onImage),
        _TableMenu(
          inTable: active.table,
          enabled: enabled,
          onSelected: (action) => onCommand(switch (action) {
            _TableAction.insert => EditorCommand.insertTable(rows: 3, cols: 3),
            _TableAction.addRow => const EditorCommand(
              EditorCommandName.addRowAfter,
            ),
            _TableAction.addColumn => const EditorCommand(
              EditorCommandName.addColumnAfter,
            ),
            _TableAction.deleteRow => const EditorCommand(
              EditorCommandName.deleteRow,
            ),
            _TableAction.deleteColumn => const EditorCommand(
              EditorCommandName.deleteColumn,
            ),
            _TableAction.deleteTable => const EditorCommand(
              EditorCommandName.deleteTable,
            ),
          }),
        ),
        action(
          Icons.horizontal_rule,
          l10n.editorDivider,
          EditorCommandName.horizontalRule,
        ),
      ],
      [
        action(
          Icons.undo,
          l10n.editorUndo,
          EditorCommandName.undo,
          available: state.canUndo,
        ),
        action(
          Icons.redo,
          l10n.editorRedo,
          EditorCommandName.redo,
          available: state.canRedo,
        ),
        action(
          Icons.format_clear,
          l10n.editorClearFormatting,
          EditorCommandName.clearFormatting,
        ),
      ],
    ];

    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: l10n.editorToolbar,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: _padding,
              vertical: _padding,
            ),
            child: Row(
              children: [
                for (final (index, group) in groups.indexed) ...[
                  if (index > 0)
                    SizedBox(
                      height: 24,
                      child: VerticalDivider(
                        width: 12,
                        color: colors.outlineVariant,
                      ),
                    ),
                  ...group,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One node with the button's label, its tap and whether it is on.
class _ToggleButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        toggled: active,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
          style: active
              ? IconButton.styleFrom(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                )
              : null,
        ),
      ),
    );
  }
}

// The menus leave the focus where it is: taking it would take it from the
// WebView, which on Android closes the keyboard and loses the caret.
class _HeadingMenu extends StatelessWidget {
  const new({
    required this.level,
    required this.enabled,
    required this.onSelected,
  });

  final int level;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    String name(int level) =>
        level == 0 ? l10n.editorParagraph : l10n.editorHeading(level);
    return MergeSemantics(
      child: Semantics(
        value: name(level),
        child: PopupMenuButton<int>(
          enabled: enabled,
          requestFocus: false,
          tooltip: l10n.editorTextStyle,
          onSelected: onSelected,
          style: level > 0
              ? IconButton.styleFrom(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                )
              : null,
          icon: const Icon(Icons.title),
          itemBuilder: (context) => [
            for (var option = 0; option <= 3; option++)
              CheckedPopupMenuItem(
                value: option,
                checked: option == level,
                child: Text(name(option)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageMenu extends StatelessWidget {
  const new({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<AttachmentSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<AttachmentSource>(
      enabled: enabled,
      requestFocus: false,
      tooltip: l10n.editorImage,
      onSelected: onSelected,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      itemBuilder: (context) => attachmentSourceItems(l10n, const [
        AttachmentSource.photos,
        AttachmentSource.camera,
        AttachmentSource.files,
      ]),
    );
  }
}

class _TableMenu extends StatelessWidget {
  const new({
    required this.inTable,
    required this.enabled,
    required this.onSelected,
  });

  final bool inTable;
  final bool enabled;
  final ValueChanged<_TableAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    PopupMenuItem<_TableAction> item(
      _TableAction action,
      String label, {
      required bool available,
    }) => PopupMenuItem(value: action, enabled: available, child: Text(label));
    return PopupMenuButton<_TableAction>(
      enabled: enabled,
      requestFocus: false,
      tooltip: l10n.editorTable,
      onSelected: onSelected,
      icon: const Icon(Icons.table_chart_outlined),
      itemBuilder: (context) => [
        item(_TableAction.insert, l10n.editorInsertTable, available: !inTable),
        item(_TableAction.addRow, l10n.editorAddRow, available: inTable),
        item(_TableAction.addColumn, l10n.editorAddColumn, available: inTable),
        item(_TableAction.deleteRow, l10n.editorDeleteRow, available: inTable),
        item(
          _TableAction.deleteColumn,
          l10n.editorDeleteColumn,
          available: inTable,
        ),
        item(
          _TableAction.deleteTable,
          l10n.editorDeleteTable,
          available: inTable,
        ),
      ],
    );
  }
}
