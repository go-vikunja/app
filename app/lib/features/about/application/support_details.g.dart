// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_details.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the support details show, collected once when the page opens.

@ProviderFor(supportSnapshot)
final supportSnapshotProvider = SupportSnapshotProvider._();

/// What the support details show, collected once when the page opens.

final class SupportSnapshotProvider
    extends
        $FunctionalProvider<
          AsyncValue<SupportSnapshot>,
          SupportSnapshot,
          FutureOr<SupportSnapshot>
        >
    with $FutureModifier<SupportSnapshot>, $FutureProvider<SupportSnapshot> {
  /// What the support details show, collected once when the page opens.
  SupportSnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportSnapshotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportSnapshotHash();

  @$internal
  @override
  $FutureProviderElement<SupportSnapshot> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SupportSnapshot> create(Ref ref) {
    return supportSnapshot(ref);
  }
}

String _$supportSnapshotHash() => r'e3584670b507e1d848fb311fab57077140cc3ce0';
