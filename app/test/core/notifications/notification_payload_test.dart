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

  test('carries the instant of the occurrence as at; one written before it '
      'has none', () {
    final at = DateTime.utc(2026, 10, 12, 10);
    final payload = NotificationPayload(
      accountId: 'acc',
      taskId: 7,
      key: '7:due',
      occurrence: at,
    );

    expect(payload.toJson(), contains('"at":${at.millisecondsSinceEpoch}'));
    expect(NotificationPayload.fromJson(payload.toJson()).occurrence, at);
    expect(
      NotificationPayload.fromJson('{"account":"acc","task":7,"key":"7:due"}')
          .occurrence,
      isNull,
    );
    expect(
      NotificationPayload.fromJson(
        '{"account":"acc","task":7,"key":"7:due","at":"soon"}',
      ).occurrence,
      isNull,
    );
  });

  test('tryParse answers null for what is no payload', () {
    expect(NotificationPayload.tryParse(null), isNull);
    expect(NotificationPayload.tryParse('{"account":1}'), isNull);
    expect(NotificationPayload.tryParse('not json'), isNull);
    expect(
      NotificationPayload.tryParse('{"account":"acc","task":7,"key":"7:due"}')
          ?.taskId,
      7,
    );
  });

  test('refuses anything else', () {
    for (final json in ['[]', '{"account":"acc","task":"7","key":"k"}']) {
      expect(() => NotificationPayload.fromJson(json), throwsFormatException);
    }
  });
}
