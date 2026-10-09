// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_link_opener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(externalLinkOpener)
final externalLinkOpenerProvider = ExternalLinkOpenerProvider._();

final class ExternalLinkOpenerProvider
    extends
        $FunctionalProvider<
          ExternalLinkOpener,
          ExternalLinkOpener,
          ExternalLinkOpener
        >
    with $Provider<ExternalLinkOpener> {
  ExternalLinkOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalLinkOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalLinkOpenerHash();

  @$internal
  @override
  $ProviderElement<ExternalLinkOpener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExternalLinkOpener create(Ref ref) {
    return externalLinkOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExternalLinkOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExternalLinkOpener>(value),
    );
  }
}

String _$externalLinkOpenerHash() =>
    r'280ff087267f19870a45da01ae3557e492f92b0b';
