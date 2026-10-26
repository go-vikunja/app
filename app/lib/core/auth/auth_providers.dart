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
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

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
WebAuthenticator webAuthenticator(Ref ref) => const FlutterWebAuthenticator();

@Riverpod(keepAlive: true)
SessionManagers sessionManagers(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  return SessionManagers(
    tokenStore: ref.watch(tokenStoreProvider),
    clockOffsets: ref.watch(serverClockOffsetsProvider),
    tokenGateway: ref.watch(tokenGatewayProvider),
    connectionFor: (accountId) async =>
        (await registry.find(accountId))?.connection,
    markNeedsReauth: registry.markNeedsReauth,
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
    final subscription = registry.changes.listen(
      (next) => state = AsyncData(next),
    );
    ref.onDispose(subscription.cancel);
    await purgeSecretsLeftByPreviousInstall(
      preferences: preferences,
      secureStore: secureStore,
    );
    final loaded = await registry.load();
    // Not awaited: the first Keystore read can be slow, and routing only
    // depends on the active account, which flagging never changes. Its
    // writes reach this provider through registry.changes.
    unawaited(
      flagAccountsWithoutTokens(
        registry,
        tokenStore,
        linkShareStore,
      ).then<void>(
        (_) {},
        onError: (Object error) =>
            _log.warning('Could not check stored tokens: ${error.runtimeType}'),
      ),
    );
    return loaded;
  }
}
