import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';

/// The user's avatar from the active account's server, the initials until
/// it has arrived and whenever there is none to draw; only decoration, like
/// [InitialsAvatar].
class UserAvatar extends ConsumerStatefulWidget {
  const new({required this.user, required this.radius, super.key});

  final User user;
  final double radius;

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  (String, String, int)? _requested;
  CachedAvatar? _avatar;

  /// Asks again on a later build once the cache has forgotten a failure
  /// that may pass, e.g. after the app was started offline.
  void _request(String accountId, AvatarCache cache, int size) {
    final key = (accountId, widget.user.username, size);
    final showsInitials = _avatar != null && _avatar!.bytes == null;
    if (key == _requested && !showsInitials) return;
    _requested = key;
    _avatar = cache.peek(widget.user.username, size);
    if (_avatar != null) return;
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
    );
    final accountId = ref.watch(activeAccountIdProvider);
    if (accountId == null || widget.user.username.isEmpty) return initials;
    final size = avatarRequestSize(
      widget.radius * 2,
      MediaQuery.devicePixelRatioOf(context),
    );
    _request(accountId, ref.watch(accountAvatarCacheProvider(accountId)), size);
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
