import 'dart:convert';

import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/notification_codec.dart';
import 'package:vikunja_api/src/realtime/realtime_message.dart';

String encodeAuthFrame(String token) =>
    jsonEncode({'action': 'auth', 'token': token});

String encodeSubscribeFrame(String event) =>
    jsonEncode({'action': 'subscribe', 'event': event});

/// Never throws: whatever this client cannot read is a [RealtimeUnknown].
RealtimeMessage decodeRealtimeMessage(Object? frame) {
  if (frame is! String) return const RealtimeUnknown();
  final Object? json;
  try {
    json = jsonDecode(frame);
  } on FormatException {
    return const RealtimeUnknown();
  }
  if (json is! Map<String, Object?>) return const RealtimeUnknown();

  if (json['error'] case final String code when code.isNotEmpty) {
    return RealtimeError(
      code,
      event: switch (json['event']) {
        final String event when event.isNotEmpty => event,
        _ => null,
      },
    );
  }
  if (json['action'] == 'auth.success' && json['success'] != false) {
    return const RealtimeAuthSucceeded();
  }
  if (json['event'] == 'notification.created') {
    try {
      return RealtimeNotification(parseServerNotification(json['data']));
    } on MalformedJson {
      return const RealtimeUnknown();
    }
  }
  return const RealtimeUnknown();
}
