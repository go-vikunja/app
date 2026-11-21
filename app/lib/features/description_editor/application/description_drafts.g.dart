// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'description_drafts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(descriptionDrafts)
final descriptionDraftsProvider = DescriptionDraftsProvider._();

final class DescriptionDraftsProvider
    extends
        $FunctionalProvider<
          DescriptionDrafts,
          DescriptionDrafts,
          DescriptionDrafts
        >
    with $Provider<DescriptionDrafts> {
  DescriptionDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'descriptionDraftsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$descriptionDraftsHash();

  @$internal
  @override
  $ProviderElement<DescriptionDrafts> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DescriptionDrafts create(Ref ref) {
    return descriptionDrafts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DescriptionDrafts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DescriptionDrafts>(value),
    );
  }
}

String _$descriptionDraftsHash() => r'25d2be9b60ac62b054280bb654d80730cd0e4fe2';
