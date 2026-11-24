// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureStore)
final secureStoreProvider = SecureStoreProvider._();

final class SecureStoreProvider
    extends $FunctionalProvider<SecureStore, SecureStore, SecureStore>
    with $Provider<SecureStore> {
  SecureStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStoreHash();

  @$internal
  @override
  $ProviderElement<SecureStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureStore create(Ref ref) {
    return secureStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureStore>(value),
    );
  }
}

String _$secureStoreHash() => r'aa467fa993206876a457815842372408ded21ef3';

@ProviderFor(preferencesStore)
final preferencesStoreProvider = PreferencesStoreProvider._();

final class PreferencesStoreProvider
    extends
        $FunctionalProvider<
          PreferencesStore,
          PreferencesStore,
          PreferencesStore
        >
    with $Provider<PreferencesStore> {
  PreferencesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesStoreHash();

  @$internal
  @override
  $ProviderElement<PreferencesStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PreferencesStore create(Ref ref) {
    return preferencesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesStore>(value),
    );
  }
}

String _$preferencesStoreHash() => r'11d7007670f4f05e0118d39119fc5699a72e12e2';

/// [preferencesStoreProvider] for what is kept as one preference per entry.

@ProviderFor(prefixedPreferencesStore)
final prefixedPreferencesStoreProvider = PrefixedPreferencesStoreProvider._();

/// [preferencesStoreProvider] for what is kept as one preference per entry.

final class PrefixedPreferencesStoreProvider
    extends
        $FunctionalProvider<
          PrefixedPreferencesStore,
          PrefixedPreferencesStore,
          PrefixedPreferencesStore
        >
    with $Provider<PrefixedPreferencesStore> {
  /// [preferencesStoreProvider] for what is kept as one preference per entry.
  PrefixedPreferencesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prefixedPreferencesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prefixedPreferencesStoreHash();

  @$internal
  @override
  $ProviderElement<PrefixedPreferencesStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrefixedPreferencesStore create(Ref ref) {
    return prefixedPreferencesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrefixedPreferencesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrefixedPreferencesStore>(value),
    );
  }
}

String _$prefixedPreferencesStoreHash() =>
    r'2e863334accdb00ca1c33faafe17fd454199215a';

@ProviderFor(tokenStore)
final tokenStoreProvider = TokenStoreProvider._();

final class TokenStoreProvider
    extends $FunctionalProvider<TokenStore, TokenStore, TokenStore>
    with $Provider<TokenStore> {
  TokenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenStoreHash();

  @$internal
  @override
  $ProviderElement<TokenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenStore create(Ref ref) {
    return tokenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenStore>(value),
    );
  }
}

String _$tokenStoreHash() => r'055f859bf8be5cbac059744d209df95ad2c607b0';

@ProviderFor(serverClockOffsets)
final serverClockOffsetsProvider = ServerClockOffsetsProvider._();

final class ServerClockOffsetsProvider
    extends
        $FunctionalProvider<
          ServerClockOffsets,
          ServerClockOffsets,
          ServerClockOffsets
        >
    with $Provider<ServerClockOffsets> {
  ServerClockOffsetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverClockOffsetsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverClockOffsetsHash();

  @$internal
  @override
  $ProviderElement<ServerClockOffsets> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ServerClockOffsets create(Ref ref) {
    return serverClockOffsets(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerClockOffsets value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerClockOffsets>(value),
    );
  }
}

String _$serverClockOffsetsHash() =>
    r'31c229e29bfc8afc33cf91d0ba1e9ae0fdd72042';

@ProviderFor(sessionDiagnostics)
final sessionDiagnosticsProvider = SessionDiagnosticsProvider._();

final class SessionDiagnosticsProvider
    extends
        $FunctionalProvider<
          SessionDiagnostics,
          SessionDiagnostics,
          SessionDiagnostics
        >
    with $Provider<SessionDiagnostics> {
  SessionDiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionDiagnosticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionDiagnosticsHash();

  @$internal
  @override
  $ProviderElement<SessionDiagnostics> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDiagnostics create(Ref ref) {
    return sessionDiagnostics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDiagnostics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDiagnostics>(value),
    );
  }
}

String _$sessionDiagnosticsHash() =>
    r'e3a873f7d59a3dc64c90ee02a7069caf4b08f553';

/// Open in the app; a background run bounds it (see [RefreshCutoff]).

@ProviderFor(refreshCutoff)
final refreshCutoffProvider = RefreshCutoffProvider._();

/// Open in the app; a background run bounds it (see [RefreshCutoff]).

final class RefreshCutoffProvider
    extends $FunctionalProvider<RefreshCutoff, RefreshCutoff, RefreshCutoff>
    with $Provider<RefreshCutoff> {
  /// Open in the app; a background run bounds it (see [RefreshCutoff]).
  RefreshCutoffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refreshCutoffProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refreshCutoffHash();

  @$internal
  @override
  $ProviderElement<RefreshCutoff> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RefreshCutoff create(Ref ref) {
    return refreshCutoff(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RefreshCutoff value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RefreshCutoff>(value),
    );
  }
}

String _$refreshCutoffHash() => r'61c2b9b69be8bc36906f0759be285c7b7a3ff99c';

@ProviderFor(accountRegistry)
final accountRegistryProvider = AccountRegistryProvider._();

final class AccountRegistryProvider
    extends
        $FunctionalProvider<AccountRegistry, AccountRegistry, AccountRegistry>
    with $Provider<AccountRegistry> {
  AccountRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRegistryHash();

  @$internal
  @override
  $ProviderElement<AccountRegistry> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountRegistry create(Ref ref) {
    return accountRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRegistry>(value),
    );
  }
}

String _$accountRegistryHash() => r'0efcdbaa14572ccdfd0170ef3abe981ad7e23892';

@ProviderFor(tokenGateway)
final tokenGatewayProvider = TokenGatewayProvider._();

final class TokenGatewayProvider
    extends $FunctionalProvider<TokenGateway, TokenGateway, TokenGateway>
    with $Provider<TokenGateway> {
  TokenGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenGatewayHash();

  @$internal
  @override
  $ProviderElement<TokenGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenGateway create(Ref ref) {
    return tokenGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenGateway>(value),
    );
  }
}

String _$tokenGatewayHash() => r'6a9e38c964e4f31878089dde688f191e5a2575a0';

@ProviderFor(accountGateway)
final accountGatewayProvider = AccountGatewayProvider._();

final class AccountGatewayProvider
    extends $FunctionalProvider<AccountGateway, AccountGateway, AccountGateway>
    with $Provider<AccountGateway> {
  AccountGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountGatewayHash();

  @$internal
  @override
  $ProviderElement<AccountGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountGateway create(Ref ref) {
    return accountGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountGateway>(value),
    );
  }
}

String _$accountGatewayHash() => r'cef1e5cd3debb68954a4623706caef78d35a9fbb';

@ProviderFor(webAuthenticator)
final webAuthenticatorProvider = WebAuthenticatorProvider._();

final class WebAuthenticatorProvider
    extends
        $FunctionalProvider<
          WebAuthenticator,
          WebAuthenticator,
          WebAuthenticator
        >
    with $Provider<WebAuthenticator> {
  WebAuthenticatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webAuthenticatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webAuthenticatorHash();

  @$internal
  @override
  $ProviderElement<WebAuthenticator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebAuthenticator create(Ref ref) {
    return webAuthenticator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAuthenticator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAuthenticator>(value),
    );
  }
}

String _$webAuthenticatorHash() => r'f39b093a88cb2f090d0a4e9fdba274058c040229';

@ProviderFor(sessionManagers)
final sessionManagersProvider = SessionManagersProvider._();

final class SessionManagersProvider
    extends
        $FunctionalProvider<SessionManagers, SessionManagers, SessionManagers>
    with $Provider<SessionManagers> {
  SessionManagersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionManagersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionManagersHash();

  @$internal
  @override
  $ProviderElement<SessionManagers> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionManagers create(Ref ref) {
    return sessionManagers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionManagers value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionManagers>(value),
    );
  }
}

String _$sessionManagersHash() => r'e9e9b6c1847aacb8316810233d3935b1d4199b70';

@ProviderFor(browserSignIn)
final browserSignInProvider = BrowserSignInProvider._();

final class BrowserSignInProvider
    extends $FunctionalProvider<BrowserSignIn, BrowserSignIn, BrowserSignIn>
    with $Provider<BrowserSignIn> {
  BrowserSignInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browserSignInProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browserSignInHash();

  @$internal
  @override
  $ProviderElement<BrowserSignIn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BrowserSignIn create(Ref ref) {
    return browserSignIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrowserSignIn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrowserSignIn>(value),
    );
  }
}

String _$browserSignInHash() => r'5b73f7a3d633d3d64c2a00d2588f89121e7bab38';

/// The registry as this isolate last read or wrote it.

@ProviderFor(Accounts)
final accountsProvider = AccountsProvider._();

/// The registry as this isolate last read or wrote it.
final class AccountsProvider
    extends $AsyncNotifierProvider<Accounts, AccountRegistryState> {
  /// The registry as this isolate last read or wrote it.
  AccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountsHash();

  @$internal
  @override
  Accounts create() => Accounts();
}

String _$accountsHash() => r'c6dc1ff13947d95eb7ed883b8b4ab0e8a0788196';

/// The registry as this isolate last read or wrote it.

abstract class _$Accounts extends $AsyncNotifier<AccountRegistryState> {
  FutureOr<AccountRegistryState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AccountRegistryState>, AccountRegistryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AccountRegistryState>,
                AccountRegistryState
              >,
              AsyncValue<AccountRegistryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
