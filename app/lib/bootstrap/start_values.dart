import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

final _log = Logger('Bootstrap');

typedef StartValues = ({
  ClientIdentity clientIdentity,
  AppLocalizations deviceL10n,
});

/// What the container needs before the first frame. Each falls back after
/// [timeout] or an error, logged by type, so that a preferences file that
/// cannot be read or a platform call that never answers does not hold the
/// app on the splash screen.
Future<StartValues> loadStartValues({
  Future<ClientIdentity> Function()? clientIdentity,
  Future<AppLocalizations> Function()? deviceL10n,
  Duration timeout = const Duration(seconds: 5),
}) async {
  Future<T> orElse<T>(
    String what,
    Future<T> Function() load,
    T Function() fallback,
  ) async {
    try {
      return await load().timeout(timeout);
    } on Object catch (error) {
      _log.severe('Could not load $what: ${error.runtimeType}');
      return fallback();
    }
  }

  final (identity, l10n) = await (
    orElse(
      'the client identity',
      clientIdentity ?? ClientIdentity.load,
      () => ClientIdentity(
        appVersion: '',
        buildNumber: '',
        platform: Platform.operatingSystem,
        osVersion: '',
      ),
    ),
    orElse(
      'the device language',
      deviceL10n ?? () => loadDeviceAppLocalizations(SharedPreferencesStore()),
      deviceAppLocalizationsWithoutNote,
    ),
  ).wait;
  return (clientIdentity: identity, deviceL10n: l10n);
}
