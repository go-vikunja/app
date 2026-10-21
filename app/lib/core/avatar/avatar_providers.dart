import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'avatar_providers.g.dart';

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials. The
/// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).
@Riverpod(keepAlive: true)
AvatarCache accountAvatarCache(Ref ref, String accountId) {
  final cache = AvatarCache(
    (username, size) => ref
        .read(readClientProvider(accountId))
        .avatars
        .fetch(username, size: size),
  );
  ref.onDispose(cache.dispose);
  return cache;
}

/// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
/// every eviction: an avatar widget keys its request on it.
@riverpod
int avatarGeneration(Ref ref, String accountId, String username) {
  final cache = ref.watch(accountAvatarCacheProvider(accountId));
  final subscription = cache.evictions
      .where((evicted) => evicted == username)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);
  return cache.generationOf(username);
}
