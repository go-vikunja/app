// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authDataHash() => r'321e34c6d952287a0371852203f99572aa89a741';

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
String _$clientProviderHash() => r'8eb84a87b52debe94e19875bcfe8ebea0727168c';

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
