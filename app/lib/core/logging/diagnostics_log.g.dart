// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostics_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This isolate's diagnostics log; null before `configureLogging`.

@ProviderFor(diagnosticsLog)
final diagnosticsLogProvider = DiagnosticsLogProvider._();

/// This isolate's diagnostics log; null before `configureLogging`.

final class DiagnosticsLogProvider
    extends
        $FunctionalProvider<DiagnosticsLog?, DiagnosticsLog?, DiagnosticsLog?>
    with $Provider<DiagnosticsLog?> {
  /// This isolate's diagnostics log; null before `configureLogging`.
  DiagnosticsLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticsLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticsLogHash();

  @$internal
  @override
  $ProviderElement<DiagnosticsLog?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiagnosticsLog? create(Ref ref) {
    return diagnosticsLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticsLog? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticsLog?>(value),
    );
  }
}

String _$diagnosticsLogHash() => r'da34215c8043d152262d1c38ddeffc02937ea03b';
