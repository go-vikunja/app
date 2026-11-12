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
}) => _share(
  context,
  ref,
  (actions, origin) => actions.shareLink(url, subject: subject, origin: origin),
  what: 'a link',
);

/// Like [shareWebLink], for [text].
Future<void> shareText(
  BuildContext context,
  WidgetRef ref, {
  required String text,
  required String subject,
}) => _share(
  context,
  ref,
  (actions, origin) =>
      actions.shareText(text, subject: subject, origin: origin),
  what: 'a text',
);

Future<void> _share(
  BuildContext context,
  WidgetRef ref,
  Future<bool> Function(LinkShareActions actions, Rect? origin) share, {
  required String what,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  var shared = false;
  try {
    shared = await share(ref.read(linkShareActionsProvider), origin);
  } on Object catch (error) {
    _log.info('Sharing $what failed: ${error.runtimeType}');
  }
  if (!shared) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareFailureGeneric)));
  }
}
