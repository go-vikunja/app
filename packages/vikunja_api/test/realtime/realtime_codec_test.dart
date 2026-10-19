import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/notification_codec.dart';
import 'package:vikunja_api/src/realtime/realtime_codec.dart';
import 'package:vikunja_api/vikunja_api.dart';

import '../helpers/fake_http_adapter.dart';

typedef _Captured = ({String name, Map<String, Object?> frame});

List<_Captured> _captured(String section) => [
  for (final entry
      in fixtureJson('realtime/frames_2.7.0.json')[section]! as List<Object?>)
    if (entry case {
      'case': final String name,
      'frame': final Map<String, Object?> frame,
    })
      (name: name, frame: frame),
];

RealtimeMessage _decode(Object? json) =>
    decodeRealtimeMessage(jsonEncode(json));

Map<String, Object?> _notificationData({
  int id = 185,
  Object? readAt = '0001-01-01T00:00:00Z',
}) => {
  'id': id,
  'notification': {
    'doer': {'id': 2, 'username': 'bob'},
    'task': {'id': 42, 'title': 'Water the plants', 'project_id': 7},
    'project': {'id': 7, 'title': 'Garden'},
  },
  'name': 'task.comment',
  'read_at': readAt,
  'created': '2026-10-19T12:45:30Z',
};

void main() {
  group('server frames captured from 2.7.0', () {
    final frames = {
      for (final (:name, :frame) in _captured('server')) name: frame,
    };

    test('auth.success', () {
      expect(_decode(frames['auth B (v2)']), isA<RealtimeAuthSucceeded>());
    });

    test('auth_required for a subscription before auth', () {
      expect(
        _decode(frames['subscribe before auth (v2)']),
        const RealtimeError(RealtimeError.authRequired),
      );
    });

    test('invalid_event names the refused event', () {
      expect(
        _decode(frames['subscribe task.updated']),
        const RealtimeError(RealtimeError.invalidEvent, event: 'task.updated'),
      );
    });

    test('invalid_token', () {
      expect(
        _decode(frames['auth without token on authenticated socket']),
        const RealtimeError(RealtimeError.invalidToken),
      );
    });
  });

  group('notification.created captured from 2.7.0', () {
    final captured = _captured('notifications');

    test('covers every kind that reaches the socket', () {
      expect(
        {for (final entry in captured) _dataOf(entry.frame)['name']},
        {
          'task.comment',
          'task.assigned',
          'task.mentioned',
          'task.created',
          'task.deleted',
          'project.created',
          'team.member.added',
          'task.reminder',
        },
      );
    });

    for (final (:name, :frame) in captured) {
      test('$name parses like a notifications list item', () {
        final data = _dataOf(frame);

        final message = decodeRealtimeMessage(jsonEncode(frame));

        expect(message, isA<RealtimeNotification>());
        final notification = (message as RealtimeNotification).notification;
        final listItem = parseServerNotification(data);
        expect(notification, listItem);
        expect(notification.payload, listItem.payload);
        expect(notification.payload, data['notification']);
        expect(notification.readAt, isNull);
        expect(notification.created.isUtc, isTrue);
      });
    }

    test('the comment frame carries the task and the project', () {
      final comment = captured.firstWhere(
        (entry) => entry.name == "comment by B on A's task",
      );

      final notification = (decodeRealtimeMessage(
        jsonEncode(comment.frame),
      ) as RealtimeNotification).notification;

      expect(notification.id, 185);
      expect(notification.name, 'task.comment');
      expect(notification.taskId, 3248);
      expect(notification.projectId, 473);
      expect(notification.created, DateTime.utc(2026, 10, 19, 12, 45, 30));
    });
  });

  group('decode', () {
    test('a read notification keeps its read date', () {
      final message = _decode({
        'event': 'notification.created',
        'data': _notificationData(readAt: '2026-10-19T13:00:00Z'),
      });

      expect(
        (message as RealtimeNotification).notification.readAt,
        DateTime.utc(2026, 10, 19, 13),
      );
    });

    test('an error code this client does not know passes through', () {
      expect(
        _decode({'error': 'forbidden', 'event': 'timer.created'}),
        const RealtimeError('forbidden', event: 'timer.created'),
      );
      expect(
        _decode({'error': 'later', 'event': ''}),
        const RealtimeError('later'),
      );
    });

    test('an error wins over the other fields', () {
      expect(
        _decode({
          'action': 'auth.success',
          'event': 'notification.created',
          'error': RealtimeError.invalidToken,
        }),
        const RealtimeError(
          RealtimeError.invalidToken,
          event: 'notification.created',
        ),
      );
    });

    final unknown = <String, Object?>{
      'null': null,
      'a binary frame': utf8.encode('{"action":"auth.success"}'),
      'text that is not JSON': 'auth.success',
      'truncated JSON': '{"action":"auth.succ',
      'a JSON array': '[]',
      'a JSON string': '"auth.success"',
      'an empty object': '{}',
      'an unknown action': '{"action":"unsubscribed","reason":"gone"}',
      'auth.success with success false':
          '{"action":"auth.success","success":false}',
      'an empty error': '{"error":""}',
      'a non-string error': '{"error":5}',
      'a timer event': '{"event":"timer.created","data":{"id":1}}',
      'notification.created without data': '{"event":"notification.created"}',
      'notification.created with a list as data':
          '{"event":"notification.created","data":[]}',
      'notification.created without an id': jsonEncode({
        'event': 'notification.created',
        'data': {..._notificationData()}..remove('id'),
      }),
      'notification.created without created': jsonEncode({
        'event': 'notification.created',
        'data': {..._notificationData(), 'created': '0001-01-01T00:00:00Z'},
      }),
    };
    for (final MapEntry(key: what, value: frame) in unknown.entries) {
      test('$what is unknown', () {
        expect(decodeRealtimeMessage(frame), isA<RealtimeUnknown>());
      });
    }
  });

  group('encode', () {
    test('auth carries the token', () {
      expect(jsonDecode(encodeAuthFrame('a.b.c')), {
        'action': 'auth',
        'token': 'a.b.c',
      });
    });

    test('subscribe names the event', () {
      expect(
        jsonDecode(encodeSubscribeFrame(RealtimeSocket.notificationCreated)),
        {'action': 'subscribe', 'event': 'notification.created'},
      );
    });
  });

  test('messages compare by value and print no payload', () {
    final notification = parseServerNotification(_notificationData());

    expect(
      RealtimeNotification(notification),
      RealtimeNotification(parseServerNotification(_notificationData())),
    );
    expect(
      RealtimeNotification(notification),
      isNot(
        RealtimeNotification(parseServerNotification(_notificationData(id: 9))),
      ),
    );
    expect(
      RealtimeNotification(notification).toString(),
      allOf(contains('185'), isNot(contains('Water the plants'))),
    );
    expect(
      const RealtimeError(RealtimeError.invalidEvent, event: 'x'),
      isNot(const RealtimeError(RealtimeError.invalidEvent)),
    );
  });
}

Map<String, Object?> _dataOf(Map<String, Object?> frame) =>
    frame['data']! as Map<String, Object?>;
