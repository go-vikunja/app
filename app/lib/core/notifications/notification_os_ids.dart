import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The plugin's integer ids. 0 is left alone and 1 is the test
/// notification of the Account tab; everything else is a 31-bit hash of
/// `<accountId>:<key>`, so the same notification gets the same id in every
/// isolate and across restarts without a counter to share. Two keys of one
/// account that hash alike are told apart by probing upwards from the
/// hash ([nextFreeNotificationOsId]). Two accounts may collide too, and a
/// schedule or a cancel under an id acts on whatever is pending there. So
/// a reconcile probes past the ids other accounts hold pending (by the
/// payload's account) and moves an entry whose id another account has
/// taken over to a free one. Races between two accounts' runs and the
/// cancels made without asking the OS (sign-out, Done) remain: what they
/// take is missing until its account's next reconcile, and lost if due
/// before it.
abstract final class NotificationOsIds {
  static const testNotification = 1;
  static const first = 2;
  static const last = 0x7fffffff;

  /// The reminders to open the app before a session ends, one per account
  /// (`sessionReminderOsId`): negative, so no hash above reaches them.
  static const sessionRemindersFirst = -0x7fffffff;
  static const sessionRemindersLast = -1;
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
