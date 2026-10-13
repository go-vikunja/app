import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'avatar_providers.g.dart';

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials.
@Riverpod(keepAlive: true)
AvatarCache accountAvatarCache(Ref ref, String accountId) => AvatarCache(
  (username, size) => ref
      .read(readClientProvider(accountId))
      .avatars
      .fetch(username, size: size),
);
