import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';

/// The user's avatar from the server of [accountId] (the active account
/// when null), the initials until it has arrived and whenever there is
/// none to draw; asked for again once the user changed it. Only
/// decoration, like [InitialsAvatar], whose [primary] colours mark the
/// user's own accounts.
class UserAvatar extends ConsumerStatefulWidget {
  const new({
    required this.user,
    required this.radius,
    this.accountId,
    this.primary = false,
    super.key,
  });

  final User user;
  final double radius;
  final String? accountId;
  final bool primary;

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  (String, String, int, int)? _requested;
  CachedAvatar? _avatar;

  /// Asks again on a later build once the cache has forgotten a failure
  /// that may pass, e.g. after the app was started offline.
  void _request(String accountId, AvatarCache cache, int size, int generation) {
    final key = (accountId, widget.user.username, size, generation);
    final showsInitials = _avatar != null && _avatar!.bytes == null;
    if (key == _requested && !showsInitials) return;
    // A new generation of the same avatar keeps the old picture until the
    // new one has arrived, so it does not flash the initials.
    final sameAvatar =
        _requested != null &&
        (_requested!.$1, _requested!.$2, _requested!.$3) ==
            (key.$1, key.$2, key.$3);
    _requested = key;
    final cached = cache.peek(widget.user.username, size);
    if (cached != null || !sameAvatar) _avatar = cached;
    if (cached != null) return;
    unawaited(
      cache.load(widget.user.username, size).then((avatar) {
        if (mounted && _requested == key) setState(() => _avatar = avatar);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = InitialsAvatar(
      name: widget.user.displayName,
      radius: widget.radius,
      primary: widget.primary,
    );
    final accountId = widget.accountId ?? ref.watch(activeAccountIdProvider);
    final username = widget.user.username;
    if (accountId == null || username.isEmpty) return initials;
    final size = avatarRequestSize(
      widget.radius * 2,
      MediaQuery.devicePixelRatioOf(context),
    );
    _request(
      accountId,
      ref.watch(accountAvatarCacheProvider(accountId)),
      size,
      ref.watch(avatarGenerationProvider(accountId, username)),
    );
    final bytes = _avatar?.bytes;
    if (bytes == null) return initials;
    final diameter = widget.radius * 2;
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.memory(
          bytes,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => initials,
        ),
      ),
    );
  }
}
