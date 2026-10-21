// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_display.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$secureDisplayHash() => r'69eefec701ad04ae4814c1bd4c73571c2fb6afbc';
