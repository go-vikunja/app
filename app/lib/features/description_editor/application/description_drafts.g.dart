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
        isAutoDispose: true,
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

String _$descriptionDraftsHash() => r'4fc14d4982f6b30ea2b8038d7b379a66e11a13b5';
