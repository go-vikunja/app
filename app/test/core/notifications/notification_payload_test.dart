import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';

void main() {
  test('reads a payload written before the link key existed', () {
    final payload = NotificationPayload.fromJson(
      '{"account":"acc","task":7,"key":"7:due"}',
    );

    expect(payload.accountId, 'acc');
    expect(payload.taskId, 7);
    expect(payload.key, '7:due');
    expect(payload.linkKey, isNull);
  });

  test('carries the link key as k, and leaves it out without one', () {
    const keyed = NotificationPayload(
      accountId: 'acc',
      taskId: 7,
      key: '7:due',
      linkKey: 'link-key-marker',
    );

    expect(keyed.toJson(), contains('"k":"link-key-marker"'));
    expect(
      NotificationPayload.fromJson(keyed.toJson()).linkKey,
      'link-key-marker',
    );
    expect(
      const NotificationPayload(
        accountId: 'acc',
        taskId: 7,
        key: '7:due',
      ).toJson(),
      '{"account":"acc","task":7,"key":"7:due"}',
    );
    expect(
      NotificationPayload.fromJson(
        '{"account":"acc","task":7,"key":"7:due","k":""}',
      ).linkKey,
      isNull,
    );
  });

  test('refuses anything else', () {
    for (final json in ['[]', '{"account":"acc","task":"7","key":"k"}']) {
      expect(() => NotificationPayload.fromJson(json), throwsFormatException);
    }
  });
}
