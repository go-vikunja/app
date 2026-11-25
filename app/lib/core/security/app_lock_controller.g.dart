// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time, by the wall clock or by [BootClock], which counts sleep too
/// and cannot be set back. Bootstrap listens.

@ProviderFor(AppLockController)
final appLockControllerProvider = AppLockControllerProvider._();

/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time, by the wall clock or by [BootClock], which counts sleep too
/// and cannot be set back. Bootstrap listens.
final class AppLockControllerProvider
    extends $NotifierProvider<AppLockController, AppLockState> {
  /// The app lock: a gate over the UI, not encryption. Locked on every cold
  /// start while it is on, and again when the app was out of sight for the
  /// chosen time, by the wall clock or by [BootClock], which counts sleep too
  /// and cannot be set back. Bootstrap listens.
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

String _$appLockControllerHash() => r'c19ef94e06f2c0b2fe72c89f489eb8efaa9956da';

/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time, by the wall clock or by [BootClock], which counts sleep too
/// and cannot be set back. Bootstrap listens.

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
