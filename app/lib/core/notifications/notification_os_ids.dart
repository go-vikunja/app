import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The plugin's integer ids. 0 is left alone and 1 is the test
/// notification of the Account tab; everything else is a 31-bit hash of
/// `<accountId>:<key>`, so the same notification gets the same id in every
/// isolate and across restarts without a counter to share. Two keys of one
/// account that hash alike are told apart by probing upwards from the
/// hash ([nextFreeNotificationOsId]); two accounts may collide, which only
/// costs the other account a reschedule on its next reconcile.
abstract final class NotificationOsIds {
  static const testNotification = 1;
  static const first = 2;
  static const last = 0x7fffffff;
}

int notificationOsIdFor(String accountId, String key) {
  final digest = sha256.convert(utf8.encode('$accountId:$key')).bytes;
  final hash =
      (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
  const span = NotificationOsIds.last - NotificationOsIds.first + 1;
  return NotificationOsIds.first + (hash & 0x7fffffff) % span;
}

/// [preferred] when free, else the next id above it that [taken] does not
/// hold, wrapping round to [NotificationOsIds.first].
int nextFreeNotificationOsId(int preferred, Set<int> taken) {
  var candidate = preferred;
  while (taken.contains(candidate)) {
    candidate = candidate == NotificationOsIds.last
        ? NotificationOsIds.first
        : candidate + 1;
  }
  return candidate;
}
