const zeroDateJson = '0001-01-01T00:00:00Z';

Map<String, Object?> userJson(int id, String username) => {
  'id': id,
  'name': '',
  'username': username,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

Map<String, Object?> labelJson(int id, String title, {String hexColor = ''}) =>
    {
      'id': id,
      'title': title,
      'description': '',
      'hex_color': hexColor,
      'created_by': userJson(1, 'alice'),
      'created': '2026-10-09T08:17:58Z',
      'updated': '2026-10-09T08:17:58Z',
    };

/// A task as 2.7.0 sends it: empty collections are null.
Map<String, Object?> taskJson(
  int id, {
  Map<String, Object?> overrides = const {},
}) => {
  'id': id,
  'title': 'Task $id',
  'description': '',
  'done': false,
  'done_at': zeroDateJson,
  'due_date': zeroDateJson,
  'reminders': null,
  'project_id': 7,
  'repeat_after': 0,
  'repeat_mode': 0,
  'priority': 0,
  'start_date': zeroDateJson,
  'end_date': zeroDateJson,
  'assignees': null,
  'labels': null,
  'hex_color': '',
  'percent_done': 0,
  'identifier': 'P7-$id',
  'index': id,
  'related_tasks': <String, Object?>{},
  'attachments': null,
  'cover_image_attachment_id': 0,
  'is_favorite': false,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
  'bucket_id': 0,
  'position': 0,
  'reactions': null,
  'created_by': userJson(1, 'alice'),
  ...overrides,
};
