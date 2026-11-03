import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('TaskDto.fromJson', () {
    test('parses every scalar field', () {
      final dto = TaskDto.fromJson(
        taskJson(id: 1, title: 'test', done: true, bucketId: 8),
      );

      expect(dto.id, 1);
      expect(dto.title, 'test');
      expect(dto.description, 'Lorem ipsum');
      expect(dto.identifier, '#1');
      expect(dto.done, isTrue);
      expect(dto.parentTaskId, 0);
      expect(dto.priority, 3);
      expect(dto.projectId, 1);
      expect(dto.bucketId, 8);
      expect(dto.createdBy!.username, 'testuser');
    });

    test('parses the four date fields and the repeat interval', () {
      final dto = TaskDto.fromJson(taskJson());

      expect(dto.dueDate, DateTime.parse(isoDate));
      expect(dto.startDate, DateTime.parse(isoDate));
      expect(dto.endDate, DateTime.parse(isoDate2));
      expect(dto.created, DateTime.parse(isoDate));
      expect(dto.updated, DateTime.parse(isoDate2));
      expect(dto.repeatAfter, const Duration(seconds: 3600));
    });

    test('parses a reminder list', () {
      final dto = TaskDto.fromJson(
        taskJson(
          reminders: [
            reminderJson(),
            reminderJson(reminder: isoDate2),
          ],
        ),
      );

      expect(dto.reminderDates.map((r) => r.reminder), [
        DateTime.parse(isoDate),
        DateTime.parse(isoDate2),
      ]);
    });

    test('maps null collections to empty lists', () {
      final dto = TaskDto.fromJson(taskJson());

      expect(dto.reminderDates, isEmpty);
      expect(dto.labels, isEmpty);
      expect(dto.subtasks, isEmpty);
      expect(dto.attachments, isEmpty);
    });

    test('parses nested labels, subtasks and attachments', () {
      final dto = TaskDto.fromJson(
        taskJson(
          labels: [labelJson(id: 5, title: 'Bug')],
          subtasks: [taskJson(id: 200, title: 'Subtask')],
          attachments: [attachmentJson(id: 3)],
        ),
      );

      expect(dto.labels.single.title, 'Bug');
      expect(dto.subtasks.single.id, 200);
      expect(dto.attachments.single.file.name, 'report.pdf');
    });

    test('turns a hex_color into an opaque Color, or null when empty', () {
      expect(
        TaskDto.fromJson(taskJson(hexColor: '196aff')).color,
        const Color(0xFF196AFF),
      );
      expect(TaskDto.fromJson(taskJson(hexColor: '')).color, isNull);
    });

    test('widens integer position and percent_done to doubles', () {
      final dto = TaskDto.fromJson(taskJson(position: 4, percentDone: 1));

      expect(dto.position, 4.0);
      expect(dto.percentDone, 1.0);
    });

    test('keeps double position and percent_done as-is', () {
      final dto = TaskDto.fromJson(taskJson(position: 4.5, percentDone: 0.25));

      expect(dto.position, 4.5);
      expect(dto.percentDone, 0.25);
    });
  });

  group('TaskDto.toJSON', () {
    test('writes the api field names', () {
      final json = TaskDto.fromJson(taskJson(bucketId: 8)).toJSON();

      expect(json['project_id'], 1);
      expect(json['bucket_id'], 8);
      expect(json['percent_done'], 0.0);
      expect(json['repeat_after'], 3600);
      expect(
        json['due_date'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });

    test('drops an empty identifier so the server assigns one', () {
      final dto = TaskDto(createdBy: null, projectId: 1);

      expect(dto.toJSON()['identifier'], isNull);
    });

    test('keeps a non-empty identifier', () {
      expect(TaskDto.fromJson(taskJson(id: 7)).toJSON()['identifier'], '#7');
    });

    test('serialises nested collections', () {
      final json = TaskDto.fromJson(
        taskJson(
          labels: [labelJson()],
          reminders: [reminderJson()],
          subtasks: [taskJson(id: 201)],
          attachments: [attachmentJson()],
        ),
      ).toJSON();

      expect(json['labels'], hasLength(1));
      expect(json['reminders'], hasLength(1));
      expect(json['subtasks'], hasLength(1));
      expect(json['attachments'], hasLength(1));
    });

    test('writes hex_color without the alpha channel, or null when unset', () {
      expect(
        TaskDto.fromJson(taskJson(hexColor: '196aff')).toJSON()['hex_color'],
        '196aff',
      );
      expect(
        TaskDto.fromJson(taskJson(hexColor: '')).toJSON()['hex_color'],
        isNull,
      );
    });
  });

  group('TaskDto domain conversion', () {
    test('toDomain carries scalars, dates and nested collections', () {
      final task = TaskDto.fromJson(
        taskJson(
          id: 1,
          title: 'test',
          done: true,
          hexColor: '196aff',
          labels: [labelJson(id: 5)],
          subtasks: [taskJson(id: 200)],
          attachments: [attachmentJson()],
          reminders: [reminderJson()],
        ),
      ).toDomain();

      expect(task.id, 1);
      expect(task.title, 'test');
      expect(task.done, isTrue);
      expect(task.color, const Color(0xFF196AFF));
      expect(task.labels.single.id, 5);
      expect(task.subtasks.single.id, 200);
      expect(task.attachments, hasLength(1));
      expect(task.reminderDates, hasLength(1));
      expect(task.dueDate, DateTime.parse(isoDate));
      expect(task.createdBy!.username, 'testuser');
    });

    test('fromDomain round-trips a fully populated task', () {
      final task = buildTask(
        id: 3,
        title: 'Round trip',
        done: true,
        priority: 4,
        bucketId: 2,
        position: 9.5,
        percentDone: 0.75,
        color: const Color(0xFF123456),
        repeatAfter: const Duration(days: 7),
        dueDate: DateTime.utc(2030, 1, 2, 3, 4),
        labels: [buildLabel(id: 6)],
        attachments: [buildAttachment()],
        subtasks: [buildTask(id: 4)],
      );

      final back = TaskDto.fromDomain(task).toDomain();

      expect(back.id, 3);
      expect(back.title, 'Round trip');
      expect(back.done, isTrue);
      expect(back.priority, 4);
      expect(back.bucketId, 2);
      expect(back.position, 9.5);
      expect(back.percentDone, 0.75);
      expect(back.color, const Color(0xFF123456));
      expect(back.repeatAfter, const Duration(days: 7));
      expect(back.dueDate, DateTime.utc(2030, 1, 2, 3, 4));
      expect(back.labels.single.id, 6);
      expect(back.attachments, hasLength(1));
      expect(back.subtasks.single.id, 4);
    });

    test('fromDomain keeps a null author null', () {
      final task = buildTask();
      task.createdBy = null;

      expect(TaskDto.fromDomain(task).createdBy, isNull);
      expect(TaskDto.fromDomain(task).toDomain().createdBy, isNull);
    });

    test('a directly constructed dto applies its defaults', () {
      final dto = TaskDto(createdBy: null, projectId: 1);

      expect(dto.id, 0);
      expect(dto.title, '');
      expect(dto.done, isFalse);
      expect(dto.labels, isEmpty);
      expect(dto.created, isNotNull);
    });
  });
}
