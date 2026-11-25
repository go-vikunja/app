// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boot_clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bootClock)
final bootClockProvider = BootClockProvider._();

final class BootClockProvider
    extends $FunctionalProvider<BootClock, BootClock, BootClock>
    with $Provider<BootClock> {
  BootClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootClockHash();

  @$internal
  @override
  $ProviderElement<BootClock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BootClock create(Ref ref) {
    return bootClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BootClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BootClock>(value),
    );
  }
}

String _$bootClockHash() => r'18c0434360a5d6185327b2ae5653f8bf068f2543';
