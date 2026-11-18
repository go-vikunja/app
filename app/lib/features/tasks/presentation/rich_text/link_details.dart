import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/platform/copy_confirmation.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('LinkDetails');

enum LinkDetailsChoice { open, copy }

/// A link's full [address] and the [host] it opens, with Copy address and,
/// when [canOpen], Open: after a long press on the link, and before a tap
/// opens one that may not go where its text says ([misleading], which
/// warns first). Null when the user closes it.
Future<LinkDetailsChoice?> showLinkDetails(
  BuildContext context, {
  required String address,
  required String? host,
  required bool misleading,
  required bool canOpen,
}) {
  final l10n = context.l10n;
  return showAdaptiveDialog<LinkDetailsChoice>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      void choose(LinkDetailsChoice? choice) =>
          Navigator.of(context).pop(choice);
      return AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.linkDetailsTitle),
        // A Cupertino dialog has no Material for the selectable address.
        content: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              if (misleading) Text(l10n.linkDetailsMismatch),
              if (host != null)
                Text(
                  l10n.linkDetailsHost(host),
                  style: theme.textTheme.titleSmall,
                ),
              SelectableText(
                address,
                style: theme.textTheme.bodyMedium?.merge(AppTheme.monospace),
              ),
            ],
          ),
        ),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => choose(null),
            child: Text(l10n.cancel),
          ),
          AdaptiveDialogAction(
            onPressed: () => choose(LinkDetailsChoice.copy),
            child: Text(l10n.linkDetailsCopy),
          ),
          if (canOpen)
            AdaptiveDialogAction(
              onPressed: () => choose(LinkDetailsChoice.open),
              isDestructive: misleading,
              child: Text(l10n.linkDetailsOpen),
            ),
        ],
      );
    },
  );
}

/// [address] to the clipboard. A link in a description or comment is no
/// secret of the app's, so the plain clipboard does. Android 13 and later
/// confirm a copy themselves.
Future<void> copyLinkAddress(
  BuildContext context,
  WidgetRef ref,
  String address,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final systemConfirms = ref.read(systemConfirmsCopiesProvider.future);
  try {
    await Clipboard.setData(ClipboardData(text: address));
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
    announce(context, l10n.copiedToClipboard);
  } else {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
  }
}
