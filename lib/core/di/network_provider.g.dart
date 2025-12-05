// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cronetEngineHash() => r'9e2b1ad521d37468e49fb6c708d8e76454ba8ac8';

/// Returns null if Cronet is unavailable or fails to initialize.
///
/// Copied from [cronetEngine].
@ProviderFor(cronetEngine)
final cronetEngineProvider = Provider<cronet_http.CronetEngine?>.internal(
  cronetEngine,
  name: r'cronetEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cronetEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CronetEngineRef = ProviderRef<cronet_http.CronetEngine?>;
String _$httpClientHash() => r'b95237f0f76abad9d51818ede124b4bcba61be94';

/// Uses Cronet on Android, CupertinoClient on iOS, IOClient as fallback.
///
/// Copied from [httpClient].
@ProviderFor(httpClient)
final httpClientProvider = Provider<http.Client>.internal(
  httpClient,
  name: r'httpClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$httpClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HttpClientRef = ProviderRef<http.Client>;
String _$clientProviderHash() => r'b593735bd3acdb835a5a03f47d8948abb4830530';

/// See also [clientProvider].
@ProviderFor(clientProvider)
final clientProviderProvider = Provider<Client>.internal(
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
typedef ClientProviderRef = ProviderRef<Client>;
String _$authDataHash() => r'37d6f0a9be23c0f1bbe648fe223fbedcd22002e5';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
