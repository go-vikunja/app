// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's notifications, newest first; stays loading while
/// no account is signed in.

@ProviderFor(inboxItems)
final inboxItemsProvider = InboxItemsProvider._();

/// The active account's notifications, newest first; stays loading while
/// no account is signed in.

final class InboxItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActivityItem>>,
          List<ActivityItem>,
          Stream<List<ActivityItem>>
        >
    with
        $FutureModifier<List<ActivityItem>>,
        $StreamProvider<List<ActivityItem>> {
  /// The active account's notifications, newest first; stays loading while
  /// no account is signed in.
  InboxItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<ActivityItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ActivityItem>> create(Ref ref) {
    return inboxItems(ref);
  }
}

String _$inboxItemsHash() => r'95b409b6cbdc975b6441b4385ef033ce70f584f2';

@ProviderFor(unreadActivityCount)
final unreadActivityCountProvider = UnreadActivityCountProvider._();

final class UnreadActivityCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  UnreadActivityCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadActivityCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadActivityCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return unreadActivityCount(ref);
  }
}

String _$unreadActivityCountHash() =>
    r'f728d7f38f54ee8eab4a32084040f15dc790beb9';
