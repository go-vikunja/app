import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('PreviousApp');

/// Keeps the previous app's [theme], `light` or `dark`, for a user account
/// on [server], the previous app's server.
Future<void> rememberPreviousAppTheme(
  PreferencesStore preferences, {
  required String theme,
  required Uri server,
}) => preferences.setString(
  previousAppThemeKey,
  jsonEncode({'theme': theme, 'server': '$server'}),
);

/// The previous app's light or dark choice becomes the color scheme of the
/// first user account on the previous app's server whose shell opens with
/// its settings synced, once, and only while that account follows the
/// system: a choice made on the web wins. A guest, an account on another
/// server, an account that has to sign in again or settings that do not
/// arrive within [settingsTimeout] leave it pending. Never throws.
Future<void> carryOverPreviousAppTheme({
  required PreferencesStore preferences,
  required RegisteredAccount? entry,
  required AccountSettingsRepository? repository,
  Duration settingsTimeout = const Duration(seconds: 10),
}) async {
  try {
    final stored = await preferences.getString(previousAppThemeKey);
    if (stored == null) return;
    final pending = _decode(stored);
    if (pending == null) {
      await preferences.remove(previousAppThemeKey);
      return;
    }
    if (entry == null ||
        entry.account.isLinkShare ||
        entry.account.needsReauth ||
        entry.account.serverRoot != pending.server ||
        repository == null) {
      return;
    }
    final AccountSettingsState state;
    try {
      // The stream's timeout, unlike a future's, also ends the database
      // query when it fires.
      state = await repository
          .watch()
          .where((state) => state.profile != null)
          .timeout(settingsTimeout)
          .first;
    } on Object catch (error) {
      _log.info('Account settings not synced yet: ${error.runtimeType}');
      return;
    }
    // Before the save, which is not tried again.
    await preferences.remove(previousAppThemeKey);
    if (state.settings.colorSchema != ColorSchema.auto) return;
    await repository.update(UserSettingsChanges(colorSchema: pending.scheme));
    _log.info('Carried over the theme of the previous app');
  } on Object catch (error) {
    _log.warning(
      'Could not carry over the theme of the previous app: '
      '${error.runtimeType}',
    );
  }
}

({ColorSchema scheme, Uri server})? _decode(String stored) {
  final Object? json;
  try {
    json = jsonDecode(stored);
  } on FormatException {
    return null;
  }
  if (json case {'theme': final String theme, 'server': final String server}) {
    final scheme = switch (theme) {
      'dark' => ColorSchema.dark,
      'light' => ColorSchema.light,
      _ => null,
    };
    final uri = Uri.tryParse(server);
    if (scheme != null && uri != null && uri.host.isNotEmpty) {
      return (scheme: scheme, server: uri);
    }
  }
  return null;
}
