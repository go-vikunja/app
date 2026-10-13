// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activityNotices)
final activityNoticesProvider = ActivityNoticesProvider._();

final class ActivityNoticesProvider
    extends
        $FunctionalProvider<
          ActivityNotifier,
          ActivityNotifier,
          ActivityNotifier
        >
    with $Provider<ActivityNotifier> {
  ActivityNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityNoticesHash();

  @$internal
  @override
  $ProviderElement<ActivityNotifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActivityNotifier create(Ref ref) {
    return activityNotices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityNotifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityNotifier>(value),
    );
  }
}

String _$activityNoticesHash() => r'2d05e311fb852a159b3787e561628ae370f42962';

/// The foreground side of activity and background sync; the foreground
/// sync scheduler reports its start, resumes and ticks here.

@ProviderFor(foregroundActivity)
final foregroundActivityProvider = ForegroundActivityProvider._();

/// The foreground side of activity and background sync; the foreground
/// sync scheduler reports its start, resumes and ticks here.

final class ForegroundActivityProvider
    extends
        $FunctionalProvider<
          ForegroundActivity,
          ForegroundActivity,
          ForegroundActivity
        >
    with $Provider<ForegroundActivity> {
  /// The foreground side of activity and background sync; the foreground
  /// sync scheduler reports its start, resumes and ticks here.
  ForegroundActivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundActivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundActivityHash();

  @$internal
  @override
  $ProviderElement<ForegroundActivity> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ForegroundActivity create(Ref ref) {
    return foregroundActivity(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ForegroundActivity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ForegroundActivity>(value),
    );
  }
}

String _$foregroundActivityHash() =>
    r'1138e8c3676d78b48c3a7c0fc10a135891462b57';
