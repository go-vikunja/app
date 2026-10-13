import 'package:vikunja_domain/vikunja_domain.dart';

/// A server notification with exactly [payload], for the inbox's rows; its
/// users are `{id, username, name}`, see [payloadUser].
ServerNotification inboxNotification({
  required int id,
  required String name,
  required DateTime created,
  Map<String, Object?> payload = const {},
  DateTime? readAt,
}) => ServerNotification(
  id: id,
  name: name,
  payload: payload,
  created: created.toUtc(),
  readAt: readAt?.toUtc(),
);

Map<String, Object?> payloadUser({
  required int id,
  required String username,
  String name = '',
}) => {'id': id, 'username': username, 'name': name};

Map<String, Object?> payloadTask({
  required int id,
  required String title,
  int index = 0,
  String identifier = '',
  int projectId = 1,
}) => {
  'id': id,
  'title': title,
  'index': index == 0 ? id : index,
  'identifier': identifier,
  'project_id': projectId,
};
