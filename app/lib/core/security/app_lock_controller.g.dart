// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time (wall clock, so deep sleep counts). Bootstrap listens.

@ProviderFor(AppLockController)
final appLockControllerProvider = AppLockControllerProvider._();

/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time (wall clock, so deep sleep counts). Bootstrap listens.
final class AppLockControllerProvider
    extends $NotifierProvider<AppLockController, AppLockState> {
  /// The app lock: a gate over the UI, not encryption. Locked on every cold
  /// start while it is on, and again when the app was out of sight for the
  /// chosen time (wall clock, so deep sleep counts). Bootstrap listens.
  AppLockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockControllerHash();

  @$internal
  @override
  AppLockController create() => AppLockController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLockState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLockState>(value),
    );
  }
}

String _$appLockControllerHash() => r'2590d859f8a48920821c71d2359fbac760bafed9';

/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time (wall clock, so deep sleep counts). Bootstrap listens.

abstract class _$AppLockController extends $Notifier<AppLockState> {
  AppLockState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLockState, AppLockState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLockState, AppLockState>,
              AppLockState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
