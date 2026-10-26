// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_server_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the active account's server had public teams turned on when the
/// account signed in; the app does not ask again while signed in.

@ProviderFor(activeServerHasPublicTeams)
final activeServerHasPublicTeamsProvider =
    ActiveServerHasPublicTeamsProvider._();

/// Whether the active account's server had public teams turned on when the
/// account signed in; the app does not ask again while signed in.

final class ActiveServerHasPublicTeamsProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the active account's server had public teams turned on when the
  /// account signed in; the app does not ask again while signed in.
  ActiveServerHasPublicTeamsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeServerHasPublicTeamsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeServerHasPublicTeamsHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return activeServerHasPublicTeams(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$activeServerHasPublicTeamsHash() =>
    r'84b217f7359ac0b47dbcf0030a139f2d2b2b0148';
