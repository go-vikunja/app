// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_display.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureWindow)
final secureWindowProvider = SecureWindowProvider._();

final class SecureWindowProvider
    extends $FunctionalProvider<SecureWindow, SecureWindow, SecureWindow>
    with $Provider<SecureWindow> {
  SecureWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureWindowHash();

  @$internal
  @override
  $ProviderElement<SecureWindow> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureWindow create(Ref ref) {
    return secureWindow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureWindow>(value),
    );
  }
}

String _$secureWindowHash() => r'0df717e4469f6038312076fedd568bf138737f37';

@ProviderFor(secureDisplay)
final secureDisplayProvider = SecureDisplayProvider._();

final class SecureDisplayProvider
    extends $FunctionalProvider<SecureDisplay, SecureDisplay, SecureDisplay>
    with $Provider<SecureDisplay> {
  SecureDisplayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureDisplayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureDisplayHash();

  @$internal
  @override
  $ProviderElement<SecureDisplay> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureDisplay create(Ref ref) {
    return secureDisplay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureDisplay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureDisplay>(value),
    );
  }
}

String _$secureDisplayHash() => r'9e84a63b7395759f46f9deca1f743cf0cf458808';
