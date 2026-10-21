import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

/// Opens [uri] outside the app, or says that the browser did not open.
Future<void> openExternalOrSay(
  BuildContext context,
  WidgetRef ref,
  Uri uri,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  if (await ref.read(externalLinkOpenerProvider).open(uri)) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.accountSettingsWebNotOpened)));
}
