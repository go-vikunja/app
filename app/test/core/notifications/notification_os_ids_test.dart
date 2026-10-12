import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';

void main() {
  test('the id is stable, positive, 31-bit and above the reserved ids', () {
    final id = notificationOsIdFor('account-a', '12:reminder:0');

    expect(id, notificationOsIdFor('account-a', '12:reminder:0'));
    expect(id, greaterThanOrEqualTo(NotificationOsIds.first));
    expect(id, lessThanOrEqualTo(NotificationOsIds.last));
    for (var i = 0; i < 1000; i++) {
      final other = notificationOsIdFor('account-$i', '$i:due');
      expect(other, inInclusiveRange(2, 0x7fffffff));
    }
  });

  test('the account and the key both change the id', () {
    final id = notificationOsIdFor('account-a', '12:reminder:0');

    expect(notificationOsIdFor('account-b', '12:reminder:0'), isNot(id));
    expect(notificationOsIdFor('account-a', '12:reminder:1'), isNot(id));
    expect(notificationOsIdFor('account-a', '12:due'), isNot(id));
  });

  test('the first four bytes of SHA-256 of "<account>:<key>"', () {
    // sha256("a:k") starts with 0x88 0x63 0xac 0x8a; masked to 31 bits and
    // mapped onto [first, last].
    const hash = 0x0863ac8a;
    const span = NotificationOsIds.last - NotificationOsIds.first + 1;
    expect(
      notificationOsIdFor('a', 'k'),
      NotificationOsIds.first + hash % span,
    );
    expect(notificationOsIdFor('a', 'k'), 140749964);
  });

  test('a taken id probes upwards and wraps round past the last one', () {
    expect(nextFreeNotificationOsId(100, {}), 100);
    expect(nextFreeNotificationOsId(100, {100, 101}), 102);
    expect(
      nextFreeNotificationOsId(NotificationOsIds.last, {
        NotificationOsIds.last,
        NotificationOsIds.first,
      }),
      NotificationOsIds.first + 1,
    );
  });
}
