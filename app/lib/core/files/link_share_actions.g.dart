// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_share_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(linkShareActions)
final linkShareActionsProvider = LinkShareActionsProvider._();

final class LinkShareActionsProvider
    extends
        $FunctionalProvider<
          LinkShareActions,
          LinkShareActions,
          LinkShareActions
        >
    with $Provider<LinkShareActions> {
  LinkShareActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkShareActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkShareActionsHash();

  @$internal
  @override
  $ProviderElement<LinkShareActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkShareActions create(Ref ref) {
    return linkShareActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkShareActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkShareActions>(value),
    );
  }
}

String _$linkShareActionsHash() => r'3989166f730fbcc443d34df13ac9d3f7a6156c09';
