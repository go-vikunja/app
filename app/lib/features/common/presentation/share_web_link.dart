import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/files/link_share_actions.dart';

final _log = Logger('ShareWebLink');

/// The system's share sheet for [url], with [subject] for apps that take
/// one, anchored on the widget of [context] on an iPad. When nothing could
/// be shared, the nearest messenger says so.
Future<void> shareWebLink(
  BuildContext context,
  WidgetRef ref, {
  required Uri url,
  required String subject,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  var shared = false;
  try {
    shared = await ref
        .read(linkShareActionsProvider)
        .shareLink(url, subject: subject, origin: origin);
  } on Object catch (error) {
    _log.info('Sharing a link failed: ${error.runtimeType}');
  }
  if (!shared) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareFailureGeneric)));
  }
}
