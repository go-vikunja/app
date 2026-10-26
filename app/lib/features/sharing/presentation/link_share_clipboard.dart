import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/platform/copy_confirmation.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('LinkShareClipboard');

/// Copies a link share's URL, whose hash is a long-lived secret, so that
/// the system does not preview it; says so unless the system does.
Future<void> copyLinkShareText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final systemConfirms = ref.read(systemConfirmsCopiesProvider.future);
  try {
    await ref.read(sensitiveClipboardProvider).copy(text);
  } on Object catch (error) {
    _log.info('Copying a link failed: ${error.runtimeType}');
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.copyToClipboardFailed)));
    return;
  }
  var confirmed = false;
  try {
    confirmed = await systemConfirms;
  } on Object {
    confirmed = false;
  }
  if (!context.mounted) return;
  unawaited(HapticFeedback.selectionClick());
  if (confirmed) {
    announce(context, l10n.linkShareCopied);
  } else {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.linkShareCopied)));
  }
}

/// A link share's URL as selectable text whose Copy, from the selection
/// menu or the keyboard, goes through [copyLinkShareText]: the plain
/// clipboard would show the secret in previews and keyboard histories.
class LinkShareText extends ConsumerStatefulWidget {
  const new(this.url, {super.key});

  final String url;

  @override
  ConsumerState<LinkShareText> createState() => _LinkShareTextState();
}

class _LinkShareTextState extends ConsumerState<LinkShareText> {
  TextSelection _selection = const TextSelection.collapsed(offset: -1);

  void _copySelection() {
    if (!_selection.isValid || _selection.isCollapsed) return;
    unawaited(
      copyLinkShareText(context, ref, _selection.textInside(widget.url)),
    );
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Actions(
      actions: {
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (_) => _copySelection(),
        ),
      },
      child: SelectableText(
        widget.url,
        style: theme.textTheme.bodyMedium?.merge(AppTheme.monospace),
        onSelectionChanged: (selection, _) => _selection = selection,
        contextMenuBuilder: _selectionMenu,
      ),
    );
  }
}
