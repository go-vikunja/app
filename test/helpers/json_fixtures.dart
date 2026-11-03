/// Canonical API payloads, shaped the way the Vikunja backend sends them.
///
/// Keeping the wire format in one place means a backend field rename is a
/// single edit, and every DTO test starts from the same realistic JSON.
library;

const String isoDate = '2024-03-14T15:09:26Z';
const String isoDate2 = '2024-04-01T08:30:00Z';

Map<String, dynamic> userJson({
  int id = 1,
  String username = 'testuser',
  String? name,
  Map<String, dynamic>? settings,
}) => {
  'id': id,
  'username': username,
  'name': ?name,
  'created': isoDate,
  'updated': isoDate,
  'settings': ?settings,
};

Map<String, dynamic> userSettingsJson({
  int defaultProjectId = 3,
  String language = 'en',
  Map<String, dynamic>? frontendSettings,
}) => {
  'default_project_id': defaultProjectId,
  'discoverable_by_email': true,
  'discoverable_by_name': false,
  'email_reminders_enabled': true,
  'frontend_settings': frontendSettings,
  'language': language,
  'name': 'Test User',
  'overdue_tasks_reminders_enabled': true,
  'overdue_tasks_reminders_time': '09:00',
  'timezone': 'Europe/Berlin',
  'week_start': 1,
};

Map<String, dynamic> labelJson({
  int id = 5,
  String title = 'Bug',
  String hexColor = 'e8e8e8',
}) => {
  'id': id,
  'title': title,
  'description': 'A defect',
  'hex_color': hexColor,
  'created': isoDate,
  'updated': isoDate,
  'created_by': userJson(),
};

Map<String, dynamic> reminderJson({String reminder = isoDate}) => {
  'reminder': reminder,
  'relative_period': 0,
  'relative_to': '',
};

Map<String, dynamic> attachmentFileJson({
  int id = 3,
  String name = 'report.pdf',
}) => {
  'id': id,
  'created': isoDate,
  'mime': 'application/pdf',
  'name': name,
  'size': 1024,
};

Map<String, dynamic> attachmentJson({int id = 3, int taskId = 100}) => {
  'id': id,
  'task_id': taskId,
  'created': isoDate,
  'created_by': userJson(),
  'file': attachmentFileJson(id: id),
};

Map<String, dynamic> taskJson({
  int id = 100,
  String title = 'Test Task',
  bool done = false,
  String hexColor = '',
  int? bucketId,
  Object position = 0,
  Object percentDone = 0,
  List<Map<String, dynamic>>? labels,
  List<Map<String, dynamic>>? reminders,
  List<Map<String, dynamic>>? subtasks,
  List<Map<String, dynamic>>? attachments,
}) => {
  'id': id,
  'title': title,
  'description': 'Lorem ipsum',
  'identifier': '#$id',
  'done': done,
  'due_date': isoDate,
  'start_date': isoDate,
  'end_date': isoDate2,
  'reminders': reminders,
  'parent_task_id': 0,
  'priority': 3,
  'repeat_after': 3600,
  'hex_color': hexColor,
  'position': position,
  'percent_done': percentDone,
  'labels': labels,
  'subtasks': subtasks,
  'attachments': attachments,
  'project_id': 1,
  'bucket_id': bucketId,
  'created': isoDate,
  'updated': isoDate2,
  'created_by': userJson(),
};

Map<String, dynamic> filterJson() => {
  's': 'search term',
  'sort_by': ['due_date', 'id'],
  'order_by': ['asc', 'desc'],
  'filter': 'done = false',
  'filter_include_nulls': false,
};

Map<String, dynamic> bucketConfigurationJson({String title = 'Backlog'}) => {
  'title': title,
  'filter': filterJson(),
};

Map<String, dynamic> bucketJson({
  int id = 50,
  String title = 'Backlog',
  int limit = 0,
  Object? position = 65536.0,
  List<Map<String, dynamic>>? tasks,
}) => {
  'id': id,
  'project_view_id': 20,
  'title': title,
  'position': position,
  'limit': limit,
  'created': isoDate,
  'updated': isoDate2,
  'created_by': userJson(),
  'tasks': tasks,
};

Map<String, dynamic> projectViewJson({
  int id = 10,
  int projectId = 1,
  String viewKind = 'list',
  Object? filter,
  List<Map<String, dynamic>>? bucketConfiguration,
}) => {
  'created': isoDate,
  'default_bucket_id': 0,
  'done_bucket_id': 0,
  'id': id,
  'filter': filter,
  'position': 0,
  'project_id': projectId,
  'title': 'List',
  'view_kind': viewKind,
  'bucket_configuration_mode': 'manual',
  'bucket_configuration': bucketConfiguration,
  'updated': isoDate2,
};

Map<String, dynamic> serverJson({String version = 'v0.24.0'}) => {
  'caldav_enabled': true,
  'email_reminders_enabled': true,
  'frontend_url': 'https://vikunja.example.com/',
  'link_sharing_enabled': true,
  'max_file_size': '20MB',
  'motd': 'Welcome',
  'registration_enabled': false,
  'task_attachments_enabled': true,
  'task_comments_enabled': true,
  'totp_enabled': false,
  'user_deletion': true,
  'version': version,
};

/// A project payload carrying every field `ProjectDto.fromJson` requires.
Map<String, dynamic> projectJson({
  int id = 1,
  String title = 'Inbox',
  String hexColor = '',
  int parentProjectId = 0,
  List<Map<String, dynamic>>? views,
  Map<String, dynamic>? owner,
}) => {
  'id': id,
  'title': title,
  'description': '',
  'hex_color': hexColor,
  'owner': owner ?? userJson(),
  'is_archived': false,
  'is_favorite': false,
  'parent_project_id': parentProjectId,
  'position': 1,
  'views': views ?? <Object>[],
  'created': isoDate,
  'updated': isoDate,
};

Map<String, dynamic> commentJson({int id = 7, String text = '<p>Nice</p>'}) => {
  'id': id,
  'comment': text,
  'author': userJson(),
  'created': isoDate,
  'updated': isoDate,
};
