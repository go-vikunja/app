// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_switcher_protection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the app switcher hides the app only as far as its own cover
/// is drawn in time: Android 12 and older, where the system cannot
/// leave the Recents thumbnail out. An unknown version counts as older.

@ProviderFor(appSwitcherBestEffort)
final appSwitcherBestEffortProvider = AppSwitcherBestEffortProvider._();

/// Whether the app switcher hides the app only as far as its own cover
/// is drawn in time: Android 12 and older, where the system cannot
/// leave the Recents thumbnail out. An unknown version counts as older.

final class AppSwitcherBestEffortProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the app switcher hides the app only as far as its own cover
  /// is drawn in time: Android 12 and older, where the system cannot
  /// leave the Recents thumbnail out. An unknown version counts as older.
  AppSwitcherBestEffortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSwitcherBestEffortProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSwitcherBestEffortHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return appSwitcherBestEffort(ref);
  }
}

String _$appSwitcherBestEffortHash() =>
    r'1e8b082102fd04c3f35303f29ae7a64718f4d019';
