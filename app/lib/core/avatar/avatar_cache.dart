import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _log = Logger('Avatars');

typedef AvatarFetch = Future<AvatarImage> Function(String username, int size);

@immutable
final class CachedAvatar {
  const new(this.bytes);

  static const initials = CachedAvatar(null);

  /// Null when the initials stand in: the request failed, or the avatar is
  /// an SVG, which the app cannot draw.
  final Uint8List? bytes;
}

/// One account's avatars for the session: the [capacity] most recently used
/// in memory, one request per avatar and size at a time, and every answer
/// remembered, so a row that scrolls back in does not ask again. A failure
/// that may pass (no connection, a server error) is remembered for
/// [retryAfter] only, so the avatars come once the server can be reached.
final class AvatarCache {
  new(
    this._fetch, {
    this.capacity = 100,
    this.retryAfter = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AvatarFetch _fetch;
  final int capacity;
  final Duration retryAfter;
  final DateTime Function() _now;
  final _avatars = <(String, int), CachedAvatar>{};
  final _retryAt = <(String, int), DateTime>{};
  final _inFlight = <(String, int), Future<CachedAvatar>>{};

  /// Null until [load] has finished for it, and again once a passing
  /// failure may be retried.
  CachedAvatar? peek(String username, int size) {
    final key = (username, size);
    if (_retryAt[key] case final retryAt? when !_now().isBefore(retryAt)) {
      _retryAt.remove(key);
      _avatars.remove(key);
      return null;
    }
    final avatar = _avatars.remove(key);
    if (avatar != null) _avatars[key] = avatar;
    return avatar;
  }

  /// Never throws.
  Future<CachedAvatar> load(String username, int size) {
    if (peek(username, size) case final avatar?) return Future.value(avatar);
    final key = (username, size);
    // whenComplete would wait for a returned future, and the removed one is
    // this very future.
    return _inFlight[key] ??= _download(
      username,
      size,
    ).whenComplete(() => unawaited(_inFlight.remove(key)));
  }

  Future<CachedAvatar> _download(String username, int size) async {
    final key = (username, size);
    CachedAvatar avatar;
    _retryAt.remove(key);
    try {
      final image = await _fetch(username, size);
      avatar = image.isSvg || image.bytes.isEmpty
          ? CachedAvatar.initials
          : CachedAvatar(image.bytes);
    } on Object catch (error) {
      _log.fine('Avatar unavailable: ${error.runtimeType}');
      avatar = CachedAvatar.initials;
      if (error is! NotFound && error is! Forbidden) {
        _retryAt[key] = _now().add(retryAfter);
      }
    }
    _avatars[key] = avatar;
    while (_avatars.length > capacity) {
      _retryAt.remove(_avatars.keys.first);
      _avatars.remove(_avatars.keys.first);
    }
    return avatar;
  }
}

const _requestSizes = [32, 64, 128, 256];

/// The pixel size to ask the server for: the next bucket up, so the sizes
/// one screen needs share their requests.
int avatarRequestSize(double logicalDiameter, double devicePixelRatio) {
  final pixels = (logicalDiameter * devicePixelRatio).ceil();
  return _requestSizes.firstWhere(
    (size) => size >= pixels,
    orElse: () => _requestSizes.last,
  );
}
