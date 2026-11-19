import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Selectable [text] whose Copy, from the selection menu or the keyboard,
/// goes to [onCopy] with the selected part, never to the plain clipboard,
/// which Android previews and keyboards remember; the menu offers only
/// Copy and Select all, so Share cannot hand the secret on either.
class SensitiveSelectableText extends StatefulWidget {
  const new(this.text, {required this.onCopy, this.style, super.key});

  final String text;
  final Future<void> Function(String selected) onCopy;
  final TextStyle? style;

  @override
  State<SensitiveSelectableText> createState() =>
      _SensitiveSelectableTextState();
}

class _SensitiveSelectableTextState extends State<SensitiveSelectableText> {
  TextSelection _selection = const TextSelection.collapsed(offset: -1);

  void _copySelection() {
    if (!_selection.isValid || _selection.isCollapsed) return;
    unawaited(widget.onCopy(_selection.textInside(widget.text)));
  }

  Widget _selectionMenu(BuildContext context, EditableTextState editable) =>
      AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editable.contextMenuAnchors,
        buttonItems: [
          for (final item in editable.contextMenuButtonItems)
            if (item.type == ContextMenuButtonType.copy)
              item.copyWith(
                onPressed: () {
                  editable.hideToolbar();
                  _copySelection();
                },
              )
            else if (item.type == ContextMenuButtonType.selectAll)
              item,
        ],
      );

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
        onInvoke: (_) => _copySelection(),
      ),
    },
    child: SelectableText(
      widget.text,
      style: widget.style,
      onSelectionChanged: (selection, _) => _selection = selection,
      contextMenuBuilder: _selectionMenu,
    ),
  );
}
