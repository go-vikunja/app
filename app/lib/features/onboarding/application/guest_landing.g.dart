// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_landing.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(guestLandings)
final guestLandingsProvider = GuestLandingsProvider._();

final class GuestLandingsProvider
    extends $FunctionalProvider<GuestLandings, GuestLandings, GuestLandings>
    with $Provider<GuestLandings> {
  GuestLandingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestLandingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestLandingsHash();

  @$internal
  @override
  $ProviderElement<GuestLandings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuestLandings create(Ref ref) {
    return guestLandings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestLandings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestLandings>(value),
    );
  }
}

String _$guestLandingsHash() => r'83d100cdcb4b2b6a98fa9c1a195005496d4cbbcd';
