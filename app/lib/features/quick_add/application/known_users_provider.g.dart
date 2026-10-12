// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'known_users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The people this device knows (the user, assignees of synced tasks and
/// earlier search results); stays loading without an account.

@ProviderFor(knownUsers)
final knownUsersProvider = KnownUsersProvider._();

/// The people this device knows (the user, assignees of synced tasks and
/// earlier search results); stays loading without an account.

final class KnownUsersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<User>>,
          List<User>,
          Stream<List<User>>
        >
    with $FutureModifier<List<User>>, $StreamProvider<List<User>> {
  /// The people this device knows (the user, assignees of synced tasks and
  /// earlier search results); stays loading without an account.
  KnownUsersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownUsersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownUsersHash();

  @$internal
  @override
  $StreamProviderElement<List<User>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<User>> create(Ref ref) {
    return knownUsers(ref);
  }
}

String _$knownUsersHash() => r'71a5f57700704c3232447337334398299eddef78';
