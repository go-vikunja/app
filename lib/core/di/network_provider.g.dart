// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authDataHash() => r'492567824201ecdff8f74abd481d5d07f5cf2faf';

/// See also [AuthData].
@ProviderFor(AuthData)
final authDataProvider = NotifierProvider<AuthData, AuthModel?>.internal(
  AuthData.new,
  name: r'authDataProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthData = Notifier<AuthModel?>;
String _$currentUserHash() => r'6c693923886cc2ac9303d1f1c51786f9b4638b0a';

/// See also [CurrentUser].
@ProviderFor(CurrentUser)
final currentUserProvider = NotifierProvider<CurrentUser, User?>.internal(
  CurrentUser.new,
  name: r'currentUserProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentUser = Notifier<User?>;
String _$oAuthTokenManagerHash() => r'9bd01017465812faa75c36febf391bb716f49e6e';

/// See also [OAuthTokenManager].
@ProviderFor(OAuthTokenManager)
final oAuthTokenManagerProvider =
    NotifierProvider<OAuthTokenManager, OAuthTokenState?>.internal(
      OAuthTokenManager.new,
      name: r'oAuthTokenManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$oAuthTokenManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OAuthTokenManager = Notifier<OAuthTokenState?>;
String _$clientProviderHash() => r'1e1930706bc0689f0082bd42e9dcdd8bac3e7fb1';

/// See also [ClientProvider].
@ProviderFor(ClientProvider)
final clientProviderProvider =
    NotifierProvider<ClientProvider, Client>.internal(
      ClientProvider.new,
      name: r'clientProviderProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$clientProviderHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ClientProvider = Notifier<Client>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
