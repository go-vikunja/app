import 'dart:convert';

import 'package:test/test.dart';
import 'package:vikunja_app/data/models/task.dart';

void main() {
  test('Check encoding with all values set', () {
    final String json =
        '{"id": 1,"text": "test","description": "Lorem Ipsum","done": true,"dueDate": 1543834800,"reminderDates": [1543834800,1544612400],"repeatAfter": 3600,"parentTaskID": 0,"priority": 100,"startDate": 1543834800,"endDate": 1543835000,"assignees": null,"labels": null,"subtasks": null,"created": 1542465818,"updated": 1552771527,"createdBy": {"id": 1,"username": "user","email": "test@example.com","created": 1537855131,"updated": 1545233325}}';
    final JsonDecoder _decoder = new JsonDecoder();
    final task = Task.fromJson(_decoder.convert(json));

    expect(task.id, 1);
    expect(task.title, 'test');
    expect(task.description, 'Lorem Ipsum');
    expect(task.done, true);
    expect(task.reminderDates, [
      DateTime.fromMillisecondsSinceEpoch(1543834800 * 1000),
      DateTime.fromMillisecondsSinceEpoch(1544612400 * 1000),
    ]);
    expect(
        task.dueDate, DateTime.fromMillisecondsSinceEpoch(1543834800 * 1000));
    expect(task.repeatAfter, Duration(seconds: 3600));
    expect(task.parentTaskId, 0);
    expect(task.priority, 100);
    expect(
        task.startDate, DateTime.fromMillisecondsSinceEpoch(1543834800 * 1000));
    expect(
        task.endDate, DateTime.fromMillisecondsSinceEpoch(1543835000 * 1000));
    expect(task.labels, null);
    expect(task.subtasks, null);
    expect(
        task.created, DateTime.fromMillisecondsSinceEpoch(1542465818 * 1000));
    expect(
        task.updated, DateTime.fromMillisecondsSinceEpoch(1552771527 * 1000));
  });
  test('Check encoding with reminder dates as null', () {
    final String json =
        '{"id": 1,"text": "test","description": "Lorem Ipsum","done": true,"dueDate": 1543834800,"reminderDates": null,"repeatAfter": 3600,"parentTaskID": 0,"priority": 100,"startDate": 1543834800,"endDate": 1543835000,"assignees": null,"labels": null,"subtasks": null,"created": 1542465818,"updated": 1552771527,"createdBy": {"id": 1,"username": "user","email": "test@example.com","created": 1537855131,"updated": 1545233325}}';
    final JsonDecoder _decoder = new JsonDecoder();
    final task = Task.fromJson(_decoder.convert(json));

    expect(task.id, 1);
    expect(task.title, 'test');
    expect(task.description, 'Lorem Ipsum');
    expect(task.done, true);
    expect(task.reminderDates, null);
    expect(
        task.dueDate, DateTime.fromMillisecondsSinceEpoch(1543834800 * 1000));
    expect(task.repeatAfter, Duration(seconds: 3600));
    expect(task.parentTaskId, 0);
    expect(task.priority, 100);
    expect(
        task.startDate, DateTime.fromMillisecondsSinceEpoch(1543834800 * 1000));
    expect(
        task.endDate, DateTime.fromMillisecondsSinceEpoch(1543835000 * 1000));
    expect(task.labels, null);
    expect(task.subtasks, null);
    expect(
        task.created, DateTime.fromMillisecondsSinceEpoch(1542465818 * 1000));
    expect(
        task.updated, DateTime.fromMillisecondsSinceEpoch(1552771527 * 1000));
  });
}
