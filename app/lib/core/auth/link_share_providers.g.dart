// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_share_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(linkShareStore)
final linkShareStoreProvider = LinkShareStoreProvider._();

final class LinkShareStoreProvider
    extends $FunctionalProvider<LinkShareStore, LinkShareStore, LinkShareStore>
    with $Provider<LinkShareStore> {
  LinkShareStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkShareStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkShareStoreHash();

  @$internal
  @override
  $ProviderElement<LinkShareStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkShareStore create(Ref ref) {
    return linkShareStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkShareStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkShareStore>(value),
    );
  }
}

String _$linkShareStoreHash() => r'217bb97b970f0af71ea28564782141221238e0b8';

@ProviderFor(linkShareGateway)
final linkShareGatewayProvider = LinkShareGatewayProvider._();

final class LinkShareGatewayProvider
    extends
        $FunctionalProvider<
          LinkShareGateway,
          LinkShareGateway,
          LinkShareGateway
        >
    with $Provider<LinkShareGateway> {
  LinkShareGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkShareGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkShareGatewayHash();

  @$internal
  @override
  $ProviderElement<LinkShareGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkShareGateway create(Ref ref) {
    return linkShareGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkShareGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkShareGateway>(value),
    );
  }
}

String _$linkShareGatewayHash() => r'f7a589bdf34eadb5376528a9a5a817e02720a82e';

/// A container the OS started without the app authenticates a guest again
/// at most once: the background job runs every half hour, and the shared
/// sign-in limit must not be spent on a password the user has to type.

@ProviderFor(linkShareSessions)
final linkShareSessionsProvider = LinkShareSessionsProvider._();

/// A container the OS started without the app authenticates a guest again
/// at most once: the background job runs every half hour, and the shared
/// sign-in limit must not be spent on a password the user has to type.

final class LinkShareSessionsProvider
    extends
        $FunctionalProvider<
          LinkShareSessions,
          LinkShareSessions,
          LinkShareSessions
        >
    with $Provider<LinkShareSessions> {
  /// A container the OS started without the app authenticates a guest again
  /// at most once: the background job runs every half hour, and the shared
  /// sign-in limit must not be spent on a password the user has to type.
  LinkShareSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkShareSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkShareSessionsHash();

  @$internal
  @override
  $ProviderElement<LinkShareSessions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LinkShareSessions create(Ref ref) {
    return linkShareSessions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkShareSessions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkShareSessions>(value),
    );
  }
}

String _$linkShareSessionsHash() => r'04de91ae05559fe4778abd5b588b97e1c9672e25';
