import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';

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
/// that may pass (no connection, a server error, an answer that is no
/// image) is remembered for [retryAfter] only, so the avatars come once
/// the server can be reached.
///
/// Behind it, an [ImageDiskCache] keeps every avatar the server sent:
/// written after each load, read when a failure may pass, and forgotten
/// with [evict]. One the disk refuses, such as an SVG, replaces the one
/// kept before.
final class AvatarCache {
  new(
    this._fetch, {
    this.capacity = 100,
    this.retryAfter = const Duration(minutes: 2),
    this._disk,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AvatarFetch _fetch;
  final ImageDiskCache? _disk;
  final int capacity;
  final Duration retryAfter;
  final DateTime Function() _now;
  final _avatars = <(String, int), CachedAvatar>{};
  final _retryAt = <(String, int), DateTime>{};
  final _inFlight = <(String, int), Future<CachedAvatar>>{};
  final _generations = <String, int>{};
  final _knownUpdates = <String, DateTime>{};
  final _evictions = StreamController<String>.broadcast(sync: true);

  /// Grows with every [evict] of the user; a widget that keys its request
  /// on it asks again.
  int generationOf(String username) => _generations[username] ?? 0;

  /// The usernames [evict] forgot.
  Stream<String> get evictions => _evictions.stream;

  /// Forgets every size of the user's avatar, which the user has just
  /// changed; an answer still on its way is not kept. [updated] is the
  /// user's `updated` after the change, so [noteUpdated] does not evict a
  /// second time for it.
  void evict(String username, {DateTime? updated}) {
    if (updated != null) _knownUpdates[username] = updated;
    _generations[username] = generationOf(username) + 1;
    bool ofUser((String, int) key) => key.$1 == username;
    _avatars.removeWhere((key, _) => ofUser(key));
    _retryAt.removeWhere((key, _) => ofUser(key));
    _inFlight.removeWhere((key, _) => ofUser(key));
    unawaited(_disk?.removeStartingWith(_diskPrefix(username)));
    if (!_evictions.isClosed) _evictions.add(username);
  }

  /// The server bumps a user's `updated` with every change to the user, the
  /// avatar included, and avatar answers carry no cache validators, so a
  /// different [updated] than the one noted before evicts; the first one
  /// noted is only remembered.
  void noteUpdated(String username, DateTime updated) {
    final known = _knownUpdates[username];
    _knownUpdates[username] = updated;
    if (known != null && known != updated) evict(username);
  }

  /// [updated] after a change that left the avatar as it was, so
  /// [noteUpdated] does not evict for it.
  void recordUpdated(String username, DateTime updated) =>
      _knownUpdates[username] = updated;

  Future<void> dispose() => _evictions.close();

  /// How long until [load] asks the server again for an avatar it answered
  /// after a failure that may pass, with the initials or the one kept on
  /// disk; null when it does not.
  Duration? untilRetry(String username, int size) {
    final retryAt = _retryAt[(username, size)];
    if (retryAt == null) return null;
    final left = retryAt.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

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
    if (_inFlight[key] case final running?) return running;
    late final Future<CachedAvatar> download;
    // After an evict, another download of the same key may be in flight.
    download = _download(username, size, generationOf(username)).whenComplete(
      () {
        if (identical(_inFlight[key], download)) {
          unawaited(_inFlight.remove(key));
        }
      },
    );
    return _inFlight[key] = download;
  }

  Future<CachedAvatar> _download(
    String username,
    int size,
    int generation,
  ) async {
    final key = (username, size);
    bool current() => generation == generationOf(username);
    CachedAvatar avatar;
    _retryAt.remove(key);
    try {
      final image = await _fetch(username, size);
      if (!_isImage(image)) {
        // As the read client refuses it: a login or maintenance page in
        // front of the server is no new avatar.
        throw const UnexpectedResponse(null, message: 'not an image');
      }
      avatar = image.isSvg || image.bytes.isEmpty
          ? CachedAvatar.initials
          : CachedAvatar(image.bytes);
      if (current()) {
        unawaited(
          _disk?.write(
            _diskKey(username, size),
            AttachmentImage(bytes: image.bytes, contentType: image.contentType),
            refusedRemoves: true,
          ),
        );
      }
    } on Object catch (error) {
      _log.fine('Avatar unavailable: ${error.runtimeType}');
      avatar = CachedAvatar.initials;
      if (!current()) return avatar;
      if (error is NotFound || error is Forbidden) {
        unawaited(_disk?.remove(_diskKey(username, size)));
      } else {
        _retryAt[key] = _now().add(retryAfter);
        final kept = await _disk?.read(_diskKey(username, size));
        // An evict while the read waited dropped what it read.
        if (kept != null && current()) avatar = CachedAvatar(kept.bytes);
      }
    }
    if (!current()) return avatar;
    _avatars[key] = avatar;
    while (_avatars.length > capacity) {
      _retryAt.remove(_avatars.keys.first);
      _avatars.remove(_avatars.keys.first);
    }
    return avatar;
  }

  static bool _isImage(AvatarImage image) =>
      image.contentType.startsWith('image/') ||
      image.contentType == 'application/octet-stream';

  /// Usernames may hold any character and be long; a hash fits a file name.
  static String _diskPrefix(String username) {
    final hash = sha256.convert(utf8.encode(username)).toString();
    return 'avatar-${hash.substring(0, 32)}-';
  }

  static String _diskKey(String username, int size) =>
      '${_diskPrefix(username)}$size';
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
