import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

ServerNotification parseServerNotification(Object? json) {
  final map = objectOf(json, 'notification');
  return ServerNotification(
    id: requireInt(map, 'id', 'notification'),
    name: requireString(map, 'name', 'notification'),
    payload: switch (map['notification']) {
      final Map<String, Object?> payload => Map.unmodifiable(payload),
      _ => const {},
    },
    created:
        dateOf(map['created']) ??
        (throw const MalformedJson('notification without created')),
    readAt: dateOf(map['read_at']),
  );
}
