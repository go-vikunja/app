// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Offline from a sync run of the active account that could not reach the
/// server until a run gets through; null while online. A run in progress
/// keeps the last outcome, so a retry does not take the banner away for
/// the length of the retry.

@ProviderFor(Offline)
final offlineProvider = OfflineProvider._();

/// Offline from a sync run of the active account that could not reach the
/// server until a run gets through; null while online. A run in progress
/// keeps the last outcome, so a retry does not take the banner away for
/// the length of the retry.
final class OfflineProvider extends $NotifierProvider<Offline, OfflineState?> {
  /// Offline from a sync run of the active account that could not reach the
  /// server until a run gets through; null while online. A run in progress
  /// keeps the last outcome, so a retry does not take the banner away for
  /// the length of the retry.
  OfflineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineHash();

  @$internal
  @override
  Offline create() => Offline();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineState?>(value),
    );
  }
}

String _$offlineHash() => r'd4a6fb7656e9e9f9c255b16f4a26baeafbcd9429';

/// Offline from a sync run of the active account that could not reach the
/// server until a run gets through; null while online. A run in progress
/// keeps the last outcome, so a retry does not take the banner away for
/// the length of the retry.

abstract class _$Offline extends $Notifier<OfflineState?> {
  OfflineState? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OfflineState?, OfflineState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OfflineState?, OfflineState?>,
              OfflineState?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
