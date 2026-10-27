// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clientIdentity)
final clientIdentityProvider = ClientIdentityProvider._();

final class ClientIdentityProvider
    extends $FunctionalProvider<ClientIdentity, ClientIdentity, ClientIdentity>
    with $Provider<ClientIdentity> {
  ClientIdentityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientIdentityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientIdentityHash();

  @$internal
  @override
  $ProviderElement<ClientIdentity> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClientIdentity create(Ref ref) {
    return clientIdentity(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClientIdentity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClientIdentity>(value),
    );
  }
}

String _$clientIdentityHash() => r'6e460b55c131f93269061eaa1a7f302652c2280e';

/// Each Dio owns its adapter over the shared profile table, which edits
/// change in place: rebuilding a Dio would tear down running syncs.

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// Each Dio owns its adapter over the shared profile table, which edits
/// change in place: rebuilding a Dio would tear down running syncs.

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Each Dio owns its adapter over the shared profile table, which edits
  /// change in place: rebuilding a Dio would tear down running syncs.
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'ba1880662f43039710a29431e18512a41915fa25';

/// For the OAuth token endpoint: no auth interceptor, and a long receive
/// timeout, because the server rotates the refresh token as soon as it
/// receives a refresh, so an abandoned response loses the session.

@ProviderFor(authDio)
final authDioProvider = AuthDioProvider._();

/// For the OAuth token endpoint: no auth interceptor, and a long receive
/// timeout, because the server rotates the refresh token as soon as it
/// receives a refresh, so an abandoned response loses the session.

final class AuthDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// For the OAuth token endpoint: no auth interceptor, and a long receive
  /// timeout, because the server rotates the refresh token as soon as it
  /// receives a refresh, so an abandoned response loses the session.
  AuthDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return authDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$authDioHash() => r'be2df70f82db48793960a3e31290051ed689550b';

@ProviderFor(serverConnector)
final serverConnectorProvider = ServerConnectorProvider._();

final class ServerConnectorProvider
    extends
        $FunctionalProvider<ServerConnector, ServerConnector, ServerConnector>
    with $Provider<ServerConnector> {
  ServerConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverConnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverConnectorHash();

  @$internal
  @override
  $ProviderElement<ServerConnector> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServerConnector create(Ref ref) {
    return serverConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerConnector>(value),
    );
  }
}

String _$serverConnectorHash() => r'0a50b7b1e758862ecdd5b6e108bd6d76dba8fd31';
