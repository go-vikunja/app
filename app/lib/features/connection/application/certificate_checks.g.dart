// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate_checks.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(certificateChecks)
final certificateChecksProvider = CertificateChecksProvider._();

final class CertificateChecksProvider
    extends
        $FunctionalProvider<
          CertificateChecks,
          CertificateChecks,
          CertificateChecks
        >
    with $Provider<CertificateChecks> {
  CertificateChecksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'certificateChecksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$certificateChecksHash();

  @$internal
  @override
  $ProviderElement<CertificateChecks> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CertificateChecks create(Ref ref) {
    return certificateChecks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CertificateChecks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CertificateChecks>(value),
    );
  }
}

String _$certificateChecksHash() => r'8dfa790fa42ffb329cd97d1fe7237f449415d235';
