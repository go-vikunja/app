import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/accounts_without_tokens.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';

part 'auth_providers.g.dart';

final _log = Logger('Accounts');

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) => FlutterSecureStore();

@Riverpod(keepAlive: true)
PreferencesStore preferencesStore(Ref ref) => SharedPreferencesStore();

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) => TokenStore(ref.watch(secureStoreProvider));

@Riverpod(keepAlive: true)
ServerClockOffsets serverClockOffsets(Ref ref) =>
    ServerClockOffsets(ref.watch(preferencesStoreProvider));

@Riverpod(keepAlive: true)
SessionDiagnostics sessionDiagnostics(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  return SessionDiagnostics(
    ref.watch(preferencesStoreProvider),
    accountExists: (accountId) async => await registry.find(accountId) != null,
  );
}

/// Open in the app; a background run bounds it (see [RefreshCutoff]).
@Riverpod(keepAlive: true)
RefreshCutoff refreshCutoff(Ref ref) => RefreshCutoff();

@Riverpod(keepAlive: true)
AccountRegistry accountRegistry(Ref ref) {
  final registry = AccountRegistry(ref.watch(preferencesStoreProvider));
  ref.onDispose(registry.dispose);
  return registry;
}

@Riverpod(keepAlive: true)
TokenGateway tokenGateway(Ref ref) =>
    ApiTokenGateway(ref.watch(authDioProvider));

@Riverpod(keepAlive: true)
AccountGateway accountGateway(Ref ref) =>
    ApiAccountGateway(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
WebAuthenticator webAuthenticator(Ref ref) =>
    FlutterWebAuthenticator(excursions: ref.watch(appExcursionsProvider));

@Riverpod(keepAlive: true)
SessionManagers sessionManagers(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  final cutoff = ref.watch(refreshCutoffProvider);
  return SessionManagers(
    tokenStore: ref.watch(tokenStoreProvider),
    clockOffsets: ref.watch(serverClockOffsetsProvider),
    tokenGateway: ref.watch(tokenGatewayProvider),
    connectionFor: (accountId) async =>
        (await registry.find(accountId))?.connection,
    markNeedsReauth: registry.markNeedsReauth,
    onSessionEnded: sessionEndRecorder(ref),
    clearNeedsReauth: registry.clearNeedsReauth,
    diagnostics: ref.watch(sessionDiagnosticsProvider),
    part: ref.watch(appPartProvider),
    mayStartRefresh: () => cutoff.allowsRefresh,
  );
}

@Riverpod(keepAlive: true)
BrowserSignIn browserSignIn(Ref ref) => BrowserSignIn(
  authenticator: ref.watch(webAuthenticatorProvider),
  tokenGateway: ref.watch(tokenGatewayProvider),
  accountGateway: ref.watch(accountGatewayProvider),
  tokenStore: ref.watch(tokenStoreProvider),
  registry: ref.watch(accountRegistryProvider),
  sessions: ref.watch(sessionManagersProvider),
  diagnostics: ref.watch(sessionDiagnosticsProvider),
);

/// The registry as this isolate last read or wrote it.
@Riverpod(keepAlive: true)
class Accounts extends _$Accounts {
  @override
  Future<AccountRegistryState> build() async {
    final registry = ref.watch(accountRegistryProvider);
    final tokenStore = ref.watch(tokenStoreProvider);
    final linkShareStore = ref.watch(linkShareStoreProvider);
    final preferences = ref.watch(preferencesStoreProvider);
    final secureStore = ref.watch(secureStoreProvider);
    final diagnostics = ref.watch(sessionDiagnosticsProvider);
    // A background run or notification action only uses the accounts: the
    // purge and the check belong to the app's start, and a fresh engine's
    // first Keystore read is where a passing failure shows.
    final headless = ref.watch(appPartProvider) != AppPart.app;
    final subscription = registry.changes.listen(
      (next) => state = AsyncData(next),
    );
    ref.onDispose(subscription.cancel);
    if (!headless) {
      await purgeSecretsLeftByPreviousInstall(
        preferences: preferences,
        secureStore: secureStore,
      );
    }
    final loaded = await registry.load();
    if (headless) return loaded;
    // Not awaited: the first Keystore read can be slow, and routing only
    // depends on the active account, which flagging never changes. Its
    // writes reach this provider through registry.changes.
    unawaited(
      flagAccountsWithoutTokens(
        registry,
        tokenStore,
        linkShareStore,
        diagnostics: diagnostics,
      ).then<void>(
        (_) {},
        onError: (Object error) =>
            _log.warning('Could not check stored tokens: ${error.runtimeType}'),
      ),
    );
    return loaded;
  }
}
