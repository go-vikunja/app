// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_report_consent.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(crashReportConsentStore)
final crashReportConsentStoreProvider = CrashReportConsentStoreProvider._();

final class CrashReportConsentStoreProvider
    extends
        $FunctionalProvider<
          CrashReportConsentStore,
          CrashReportConsentStore,
          CrashReportConsentStore
        >
    with $Provider<CrashReportConsentStore> {
  CrashReportConsentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportConsentStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportConsentStoreHash();

  @$internal
  @override
  $ProviderElement<CrashReportConsentStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrashReportConsentStore create(Ref ref) {
    return crashReportConsentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashReportConsentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashReportConsentStore>(value),
    );
  }
}

String _$crashReportConsentStoreHash() =>
    r'c11e728e4807f8e2876ef13c1c6960e65cb23bb1';

/// The device's answer. One that cannot be read counts as declined, so
/// nothing is sent and nothing asked until it can be read again.

@ProviderFor(CrashReportConsentController)
final crashReportConsentControllerProvider =
    CrashReportConsentControllerProvider._();

/// The device's answer. One that cannot be read counts as declined, so
/// nothing is sent and nothing asked until it can be read again.
final class CrashReportConsentControllerProvider
    extends
        $AsyncNotifierProvider<
          CrashReportConsentController,
          CrashReportConsent
        > {
  /// The device's answer. One that cannot be read counts as declined, so
  /// nothing is sent and nothing asked until it can be read again.
  CrashReportConsentControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportConsentControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportConsentControllerHash();

  @$internal
  @override
  CrashReportConsentController create() => CrashReportConsentController();
}

String _$crashReportConsentControllerHash() =>
    r'e0ce0df1ac39237542ee7557629008ab129a503b';

/// The device's answer. One that cannot be read counts as declined, so
/// nothing is sent and nothing asked until it can be read again.

abstract class _$CrashReportConsentController
    extends $AsyncNotifier<CrashReportConsent> {
  FutureOr<CrashReportConsent> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CrashReportConsent>, CrashReportConsent>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CrashReportConsent>, CrashReportConsent>,
              AsyncValue<CrashReportConsent>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
