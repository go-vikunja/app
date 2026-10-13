import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

ServerNotification serverNotificationFromRow(ServerNotificationRow row) =>
    ServerNotification(
      id: row.id,
      name: row.name,
      payload: _decodePayload(row.payload),
      created: row.created,
      readAt: row.readAt,
    );

String encodeNotificationPayload(Map<String, Object?> payload) =>
    jsonEncode(payload);

Map<String, Object?> _decodePayload(String json) {
  try {
    if (jsonDecode(json) case final Map<String, Object?> payload) {
      return payload;
    }
  } on FormatException {
    // Written by this app, so only a corrupt file gets here.
  }
  return const {};
}
