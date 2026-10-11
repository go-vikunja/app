// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every label the account can attach, by title; stays loading without an
/// account.

@ProviderFor(allLabels)
final allLabelsProvider = AllLabelsProvider._();

/// Every label the account can attach, by title; stays loading without an
/// account.

final class AllLabelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Label>>,
          List<Label>,
          Stream<List<Label>>
        >
    with $FutureModifier<List<Label>>, $StreamProvider<List<Label>> {
  /// Every label the account can attach, by title; stays loading without an
  /// account.
  AllLabelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allLabelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allLabelsHash();

  @$internal
  @override
  $StreamProviderElement<List<Label>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Label>> create(Ref ref) {
    return allLabels(ref);
  }
}

String _$allLabelsHash() => r'3d7d04c4fc4b501f40c29107f3fd32d3a8959f9c';
