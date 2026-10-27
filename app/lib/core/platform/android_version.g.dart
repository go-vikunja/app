// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The major Android version the app remembered when it started; null when
/// it is unknown or the app does not run on Android.

@ProviderFor(androidMajorVersion)
final androidMajorVersionProvider = AndroidMajorVersionProvider._();

/// The major Android version the app remembered when it started; null when
/// it is unknown or the app does not run on Android.

final class AndroidMajorVersionProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// The major Android version the app remembered when it started; null when
  /// it is unknown or the app does not run on Android.
  AndroidMajorVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'androidMajorVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$androidMajorVersionHash();

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    return androidMajorVersion(ref);
  }
}

String _$androidMajorVersionHash() =>
    r'f0e639a57757ee450a3ca80db1134a405d1ee5a9';
