import 'dart:convert';

import 'package:test/test.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

void main() {
  test('Check encoding with all values set', () {
    final String json =
        '{"id": 1,"title": "test","description": "Lorem Ipsum","identifier": "task-1","done": true,"due_date": "2018-12-03T07:00:00Z","reminders": [{"reminder": "2018-12-03T07:00:00Z","relative_period": 0,"relative_to": ""},{"reminder": "2018-12-04T08:00:00Z","relative_period": 0,"relative_to": ""}],"repeat_after": 3600,"parent_task_id": 0,"priority": 100,"start_date": "2018-12-03T07:00:00Z","end_date": "2018-12-03T07:03:20Z","hex_color": "","position": 0,"percent_done": 0,"assignees": null,"labels": null,"subtasks": null,"attachments": null,"project_id": 1,"bucket_id": null,"created": "2018-11-17T14:56:58Z","updated": "2019-03-16T17:25:27Z","created_by": {"id": 1,"username": "user","email": "test@example.com","created": "2018-09-24T20:58:51Z","updated": "2018-12-19T19:15:25Z"}}';
    final JsonDecoder _decoder = new JsonDecoder();
    final task = TaskDto.fromJson(_decoder.convert(json));

    expect(task.id, 1);
    expect(task.title, 'test');
    expect(task.description, 'Lorem Ipsum');
    expect(task.done, true);
    expect(task.reminderDates.length, 2);
    expect(
        task.reminderDates[0].reminder, DateTime.parse('2018-12-03T07:00:00Z'));
    expect(
        task.reminderDates[1].reminder, DateTime.parse('2018-12-04T08:00:00Z'));
    expect(task.dueDate, DateTime.parse('2018-12-03T07:00:00Z'));
    expect(task.repeatAfter, Duration(seconds: 3600));
    expect(task.parentTaskId, 0);
    expect(task.priority, 100);
    expect(task.startDate, DateTime.parse('2018-12-03T07:00:00Z'));
    expect(task.endDate, DateTime.parse('2018-12-03T07:03:20Z'));
    expect(task.labels, []);
    expect(task.subtasks, []);
    expect(task.created, DateTime.parse('2018-11-17T14:56:58Z'));
    expect(task.updated, DateTime.parse('2019-03-16T17:25:27Z'));
  });
  test('Check encoding with reminder dates as null', () {
    final String json =
        '{"id": 1,"title": "test","description": "Lorem Ipsum","identifier": "task-1","done": true,"due_date": "2018-12-03T07:00:00Z","reminders": null,"repeat_after": 3600,"parent_task_id": 0,"priority": 100,"start_date": "2018-12-03T07:00:00Z","end_date": "2018-12-03T07:03:20Z","hex_color": "","position": 0,"percent_done": 0,"assignees": null,"labels": null,"subtasks": null,"attachments": null,"project_id": 1,"bucket_id": null,"created": "2018-11-17T14:56:58Z","updated": "2019-03-16T17:25:27Z","created_by": {"id": 1,"username": "user","email": "test@example.com","created": "2018-09-24T20:58:51Z","updated": "2018-12-19T19:15:25Z"}}';
    final JsonDecoder _decoder = new JsonDecoder();
    final task = TaskDto.fromJson(_decoder.convert(json));

    expect(task.id, 1);
    expect(task.title, 'test');
    expect(task.description, 'Lorem Ipsum');
    expect(task.done, true);
    expect(task.reminderDates, []);
    expect(task.dueDate, DateTime.parse('2018-12-03T07:00:00Z'));
    expect(task.repeatAfter, Duration(seconds: 3600));
    expect(task.parentTaskId, 0);
    expect(task.priority, 100);
    expect(task.startDate, DateTime.parse('2018-12-03T07:00:00Z'));
    expect(task.endDate, DateTime.parse('2018-12-03T07:03:20Z'));
    expect(task.labels, []);
    expect(task.subtasks, []);
    expect(task.created, DateTime.parse('2018-11-17T14:56:58Z'));
    expect(task.updated, DateTime.parse('2019-03-16T17:25:27Z'));
  });
}
