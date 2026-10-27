// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_authenticator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceAuthenticator)
final deviceAuthenticatorProvider = DeviceAuthenticatorProvider._();

final class DeviceAuthenticatorProvider
    extends
        $FunctionalProvider<
          DeviceAuthenticator,
          DeviceAuthenticator,
          DeviceAuthenticator
        >
    with $Provider<DeviceAuthenticator> {
  DeviceAuthenticatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAuthenticatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAuthenticatorHash();

  @$internal
  @override
  $ProviderElement<DeviceAuthenticator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceAuthenticator create(Ref ref) {
    return deviceAuthenticator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceAuthenticator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceAuthenticator>(value),
    );
  }
}

String _$deviceAuthenticatorHash() =>
    r'b8a84a3a0d8ce9db8ca168dd234b1092bdfa1ff9';

/// Asked again whenever the app comes back to the front, because the user
/// sets up a screen lock in the system settings.

@ProviderFor(DeviceAuthSupported)
final deviceAuthSupportedProvider = DeviceAuthSupportedProvider._();

/// Asked again whenever the app comes back to the front, because the user
/// sets up a screen lock in the system settings.
final class DeviceAuthSupportedProvider
    extends $AsyncNotifierProvider<DeviceAuthSupported, bool> {
  /// Asked again whenever the app comes back to the front, because the user
  /// sets up a screen lock in the system settings.
  DeviceAuthSupportedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAuthSupportedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAuthSupportedHash();

  @$internal
  @override
  DeviceAuthSupported create() => DeviceAuthSupported();
}

String _$deviceAuthSupportedHash() =>
    r'5bc76333440e01498bd0dfe1e23a6ce358aa5e37';

/// Asked again whenever the app comes back to the front, because the user
/// sets up a screen lock in the system settings.

abstract class _$DeviceAuthSupported extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
