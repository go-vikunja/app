// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the router feeds: it hands every pushed URI to `accept` first.

@ProviderFor(deepLinkRelay)
final deepLinkRelayProvider = DeepLinkRelayProvider._();

/// What the router feeds: it hands every pushed URI to `accept` first.

final class DeepLinkRelayProvider
    extends $FunctionalProvider<DeepLinkRelay, DeepLinkRelay, DeepLinkRelay>
    with $Provider<DeepLinkRelay> {
  /// What the router feeds: it hands every pushed URI to `accept` first.
  DeepLinkRelayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepLinkRelayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepLinkRelayHash();

  @$internal
  @override
  $ProviderElement<DeepLinkRelay> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeepLinkRelay create(Ref ref) {
    return deepLinkRelay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeepLinkRelay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeepLinkRelay>(value),
    );
  }
}

String _$deepLinkRelayHash() => r'2e99777901fd7aec2310cdc539735dc2cc256dc1';

/// Where the app takes deep links from; tests replace it with a fake.

@ProviderFor(deepLinkSource)
final deepLinkSourceProvider = DeepLinkSourceProvider._();

/// Where the app takes deep links from; tests replace it with a fake.

final class DeepLinkSourceProvider
    extends $FunctionalProvider<DeepLinkSource, DeepLinkSource, DeepLinkSource>
    with $Provider<DeepLinkSource> {
  /// Where the app takes deep links from; tests replace it with a fake.
  DeepLinkSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepLinkSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepLinkSourceHash();

  @$internal
  @override
  $ProviderElement<DeepLinkSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeepLinkSource create(Ref ref) {
    return deepLinkSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeepLinkSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeepLinkSource>(value),
    );
  }
}

String _$deepLinkSourceHash() => r'f80839960b87dc9830b4ecc3a497592bb849eb3e';

/// Where the app takes the links of its home-screen widgets from; tests
/// replace it with a fake.

@ProviderFor(widgetLinkSource)
final widgetLinkSourceProvider = WidgetLinkSourceProvider._();

/// Where the app takes the links of its home-screen widgets from; tests
/// replace it with a fake.

final class WidgetLinkSourceProvider
    extends $FunctionalProvider<DeepLinkSource, DeepLinkSource, DeepLinkSource>
    with $Provider<DeepLinkSource> {
  /// Where the app takes the links of its home-screen widgets from; tests
  /// replace it with a fake.
  WidgetLinkSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetLinkSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetLinkSourceHash();

  @$internal
  @override
  $ProviderElement<DeepLinkSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeepLinkSource create(Ref ref) {
    return widgetLinkSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeepLinkSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeepLinkSource>(value),
    );
  }
}

String _$widgetLinkSourceHash() => r'd6df7df309a60c70121fc95f312d1759e5b06176';
