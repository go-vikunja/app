// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_report_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [buildCrashReportsDsn]; tests override it.

@ProviderFor(crashReportsDsn)
final crashReportsDsnProvider = CrashReportsDsnProvider._();

/// [buildCrashReportsDsn]; tests override it.

final class CrashReportsDsnProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// [buildCrashReportsDsn]; tests override it.
  CrashReportsDsnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportsDsnProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportsDsnHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return crashReportsDsn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$crashReportsDsnHash() => r'30a0e0cc5f78682d2abe14dd3755a053237e4db3';

@ProviderFor(crashReportSdk)
final crashReportSdkProvider = CrashReportSdkProvider._();

final class CrashReportSdkProvider
    extends $FunctionalProvider<CrashReportSdk, CrashReportSdk, CrashReportSdk>
    with $Provider<CrashReportSdk> {
  CrashReportSdkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportSdkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportSdkHash();

  @$internal
  @override
  $ProviderElement<CrashReportSdk> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrashReportSdk create(Ref ref) {
    return crashReportSdk(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashReportSdk value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashReportSdk>(value),
    );
  }
}

String _$crashReportSdkHash() => r'99f70f54480b40a794924dca933b8a343a0c5f2f';

/// The app's reporter: it follows the device's choice at once and leaves
/// the registered servers' hosts out of every report. Bootstrap listens
/// to it for the app's lifetime.

@ProviderFor(crashReporter)
final crashReporterProvider = CrashReporterProvider._();

/// The app's reporter: it follows the device's choice at once and leaves
/// the registered servers' hosts out of every report. Bootstrap listens
/// to it for the app's lifetime.

final class CrashReporterProvider
    extends $FunctionalProvider<CrashReporter, CrashReporter, CrashReporter>
    with $Provider<CrashReporter> {
  /// The app's reporter: it follows the device's choice at once and leaves
  /// the registered servers' hosts out of every report. Bootstrap listens
  /// to it for the app's lifetime.
  CrashReporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReporterHash();

  @$internal
  @override
  $ProviderElement<CrashReporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrashReporter create(Ref ref) {
    return crashReporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashReporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashReporter>(value),
    );
  }
}

String _$crashReporterHash() => r'56421108b4ed2c5cbda4dc3905dafe9b2bf058cd';
