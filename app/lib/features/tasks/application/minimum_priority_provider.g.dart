// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minimum_priority_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lowest priority a task row labels; the web's default until the
/// settings are read.

@ProviderFor(minimumPriority)
final minimumPriorityProvider = MinimumPriorityProvider._();

/// The lowest priority a task row labels; the web's default until the
/// settings are read.

final class MinimumPriorityProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// The lowest priority a task row labels; the web's default until the
  /// settings are read.
  MinimumPriorityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'minimumPriorityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$minimumPriorityHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return minimumPriority(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$minimumPriorityHash() => r'c0b2a611ab25a327ae01585ba951d055d2cdf5d3';
