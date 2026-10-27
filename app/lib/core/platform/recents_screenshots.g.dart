// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recents_screenshots.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recentsScreenshots)
final recentsScreenshotsProvider = RecentsScreenshotsProvider._();

final class RecentsScreenshotsProvider
    extends
        $FunctionalProvider<
          RecentsScreenshots,
          RecentsScreenshots,
          RecentsScreenshots
        >
    with $Provider<RecentsScreenshots> {
  RecentsScreenshotsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentsScreenshotsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentsScreenshotsHash();

  @$internal
  @override
  $ProviderElement<RecentsScreenshots> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecentsScreenshots create(Ref ref) {
    return recentsScreenshots(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentsScreenshots value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentsScreenshots>(value),
    );
  }
}

String _$recentsScreenshotsHash() =>
    r'9e49410cff2de1a1d1f2fbab31c752cbe8bf1179';

/// Whether the system itself keeps Rurana out of the Recents screen while
/// the app lock is on (Android 13+), as [RecentsScreenshots.setEnabled]
/// last answered; the lock then needs no cover of its own. False until it
/// answered, so the cover stands in.

@ProviderFor(RecentsHiddenNatively)
final recentsHiddenNativelyProvider = RecentsHiddenNativelyProvider._();

/// Whether the system itself keeps Rurana out of the Recents screen while
/// the app lock is on (Android 13+), as [RecentsScreenshots.setEnabled]
/// last answered; the lock then needs no cover of its own. False until it
/// answered, so the cover stands in.
final class RecentsHiddenNativelyProvider
    extends $NotifierProvider<RecentsHiddenNatively, bool> {
  /// Whether the system itself keeps Rurana out of the Recents screen while
  /// the app lock is on (Android 13+), as [RecentsScreenshots.setEnabled]
  /// last answered; the lock then needs no cover of its own. False until it
  /// answered, so the cover stands in.
  RecentsHiddenNativelyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentsHiddenNativelyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentsHiddenNativelyHash();

  @$internal
  @override
  RecentsHiddenNatively create() => RecentsHiddenNatively();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$recentsHiddenNativelyHash() =>
    r'808c1f37d536e15e43af0e1e2bf7b7d43dfd93c3';

/// Whether the system itself keeps Rurana out of the Recents screen while
/// the app lock is on (Android 13+), as [RecentsScreenshots.setEnabled]
/// last answered; the lock then needs no cover of its own. False until it
/// answered, so the cover stands in.

abstract class _$RecentsHiddenNatively extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
