// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiet_sync_indicator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the quiet indicator under the app bars shows: once a sync after
/// the first has run for [showAfter], until it ends. One state for every
/// screen, so a screen opened during a long run shows it at once.

@ProviderFor(QuietSyncIndicator)
final quietSyncIndicatorProvider = QuietSyncIndicatorProvider._();

/// Whether the quiet indicator under the app bars shows: once a sync after
/// the first has run for [showAfter], until it ends. One state for every
/// screen, so a screen opened during a long run shows it at once.
final class QuietSyncIndicatorProvider
    extends $NotifierProvider<QuietSyncIndicator, bool> {
  /// Whether the quiet indicator under the app bars shows: once a sync after
  /// the first has run for [showAfter], until it ends. One state for every
  /// screen, so a screen opened during a long run shows it at once.
  QuietSyncIndicatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quietSyncIndicatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quietSyncIndicatorHash();

  @$internal
  @override
  QuietSyncIndicator create() => QuietSyncIndicator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$quietSyncIndicatorHash() =>
    r'e968d1b3e637df8f01bd052ae06b0e545160fd3f';

/// Whether the quiet indicator under the app bars shows: once a sync after
/// the first has run for [showAfter], until it ends. One state for every
/// screen, so a screen opened during a long run shows it at once.

abstract class _$QuietSyncIndicator extends $Notifier<bool> {
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
