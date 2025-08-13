// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$clientProviderHash() => r'ed390f45fd4ac4640527866c29aba901835c74cf';

/// See also [clientProvider].
@ProviderFor(clientProvider)
final clientProviderProvider = AutoDisposeProvider<Client>.internal(
  clientProvider,
  name: r'clientProviderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$clientProviderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ClientProviderRef = AutoDisposeProviderRef<Client>;
String _$authTokenHash() => r'f88d96892ae660850c8e4cbe0c29542869e15b16';

/// See also [AuthToken].
@ProviderFor(AuthToken)
final authTokenProvider = NotifierProvider<AuthToken, String?>.internal(
  AuthToken.new,
  name: r'authTokenProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authTokenHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthToken = Notifier<String?>;
String _$serverAddressHash() => r'2cbdfc96590e7b0c235e5a764411e18bcfc733a9';

/// See also [ServerAddress].
@ProviderFor(ServerAddress)
final serverAddressProvider = NotifierProvider<ServerAddress, String?>.internal(
  ServerAddress.new,
  name: r'serverAddressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$serverAddressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerAddress = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
