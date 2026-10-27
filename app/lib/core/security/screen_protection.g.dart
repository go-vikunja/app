// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_protection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the window in step with the privacy settings: no Recents
/// thumbnail while the app lock is on (Android 13+), `FLAG_SECURE` while
/// Block screenshots is on. Bootstrap listens once the app runs.

@ProviderFor(screenProtection)
final screenProtectionProvider = ScreenProtectionProvider._();

/// Keeps the window in step with the privacy settings: no Recents
/// thumbnail while the app lock is on (Android 13+), `FLAG_SECURE` while
/// Block screenshots is on. Bootstrap listens once the app runs.

final class ScreenProtectionProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Keeps the window in step with the privacy settings: no Recents
  /// thumbnail while the app lock is on (Android 13+), `FLAG_SECURE` while
  /// Block screenshots is on. Bootstrap listens once the app runs.
  ScreenProtectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenProtectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenProtectionHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return screenProtection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$screenProtectionHash() => r'35eb1b50917b862d59598c47f74185f1c55791ff';
