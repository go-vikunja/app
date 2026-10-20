// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shares from other apps; iOS gets its share extension in the iOS phase
/// and has none until then.

@ProviderFor(shareIntentSource)
final shareIntentSourceProvider = ShareIntentSourceProvider._();

/// Shares from other apps; iOS gets its share extension in the iOS phase
/// and has none until then.

final class ShareIntentSourceProvider
    extends
        $FunctionalProvider<
          ShareIntentSource,
          ShareIntentSource,
          ShareIntentSource
        >
    with $Provider<ShareIntentSource> {
  /// Shares from other apps; iOS gets its share extension in the iOS phase
  /// and has none until then.
  ShareIntentSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareIntentSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareIntentSourceHash();

  @$internal
  @override
  $ProviderElement<ShareIntentSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShareIntentSource create(Ref ref) {
    return shareIntentSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareIntentSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareIntentSource>(value),
    );
  }
}

String _$shareIntentSourceHash() => r'd96bb24d2de4bbae3bd5887203e736916afdcd59';
