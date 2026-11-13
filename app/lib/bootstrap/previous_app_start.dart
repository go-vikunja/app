import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';

final _log = Logger('Bootstrap');

/// Before the registry's first read: on a first start it wipes the secure
/// storage this reads. Null on any failure and when [timeout] passes;
/// parts that finish later find no use for a token.
Future<PreviousAppFindings?> importPreviousApp(
  ProviderContainer container, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    return await PreviousAppImport(
      preferences: container.read(preferencesStoreProvider),
      secureStore: container.read(secureStoreProvider),
      platform: container.read(previousAppPlatformProvider),
    ).run().timeout(timeout);
  } on Object catch (error) {
    _log.warning('Could not import the previous app: ${error.runtimeType}');
    return null;
  }
}

/// After the registry's first read. The previous app's session is tried
/// only once that read's wipe has deleted its stored tokens (the install
/// marker is set) and while no account is registered. Never throws.
Future<void> startPreviousApp(
  ProviderContainer container,
  PreviousAppFindings? findings,
) async {
  try {
    await container.read(previousAppProvider.future);
    if (findings == null) return;
    final notifier = container.read(previousAppProvider.notifier)
      ..noteImported(findings);
    // Without a server, keepSession does nothing.
    final refreshToken = findings.refreshToken;
    if (refreshToken == null) return;
    final marker = await container
        .read(preferencesStoreProvider)
        .getString(installMarkerKey);
    final accounts = container.read(accountsProvider).value?.accounts;
    if (marker == null || accounts == null || accounts.isNotEmpty) return;
    unawaited(notifier.keepSession(refreshToken));
  } on Object catch (error) {
    _log.warning(
      'Could not take over from the previous app: ${error.runtimeType}',
    );
  }
}
