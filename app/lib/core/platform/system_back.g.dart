// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_back.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Android hands system back to the framework only as a pop, as it
/// does before version 14; from 14 on it comes as a predictive back
/// gesture, which the routes take themselves. An unknown version counts as
/// 14.

@ProviderFor(systemBackArrivesAsPop)
final systemBackArrivesAsPopProvider = SystemBackArrivesAsPopProvider._();

/// Whether Android hands system back to the framework only as a pop, as it
/// does before version 14; from 14 on it comes as a predictive back
/// gesture, which the routes take themselves. An unknown version counts as
/// 14.

final class SystemBackArrivesAsPopProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether Android hands system back to the framework only as a pop, as it
  /// does before version 14; from 14 on it comes as a predictive back
  /// gesture, which the routes take themselves. An unknown version counts as
  /// 14.
  SystemBackArrivesAsPopProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemBackArrivesAsPopProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemBackArrivesAsPopHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return systemBackArrivesAsPop(ref);
  }
}

String _$systemBackArrivesAsPopHash() =>
    r'659cb9efb84cf53409cc979e1dd904d808ea723b';
