// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$clientProviderHash() => r'5b68f6922e1223e1b0a4d106a013c69df0c052c6';

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
