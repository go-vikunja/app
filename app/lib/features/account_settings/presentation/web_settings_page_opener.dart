import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/common/presentation/external_link.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

/// Opens one of the web's settings pages for [entry] in the browser.
Future<void> openWebSettingsPage(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry,
  WebSettingsPage page,
) {
  // The access token outlives a session that a password change or turning
  // on two-factor authentication ended.
  if (page == WebSettingsPage.password || page == WebSettingsPage.totp) {
    ref.read(sessionCheckProvider).refreshOnNextCheck(entry.id);
  }
  return openExternalOrSay(
    context,
    ref,
    webSettingsPageUri(entry.connection, page),
  );
}
