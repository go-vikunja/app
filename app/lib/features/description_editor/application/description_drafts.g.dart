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

String _$descriptionDraftsHash() => r'd5f82663acf4b248f48de5a409fbf45e474d8a6e';
