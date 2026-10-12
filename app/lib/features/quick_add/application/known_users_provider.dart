import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'known_users_provider.g.dart';

/// The people this device knows (the user, assignees of synced tasks and
/// earlier search results); stays loading without an account.
@riverpod
Stream<List<User>> knownUsers(Ref ref) =>
    ref.watch(userRepositoryProvider)?.watchKnownUsers() ??
    const Stream.empty();
