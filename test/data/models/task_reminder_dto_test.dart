import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/task_reminder_dto.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';

import '../../helpers/json_fixtures.dart';

void main() {
  group('TaskReminderDto', () {
    test('fromJson parses the reminder and its relative fields', () {
      final dto = TaskReminderDto.fromJson({
        'reminder': isoDate,
        'relative_period': -3600,
        'relative_to': 'due_date',
      });

      expect(dto.reminder, DateTime.parse(isoDate));
      expect(dto.relativePeriod, -3600);
      expect(dto.relativeTo, 'due_date');
    });

    test('toJSON writes the api keys with a utc timestamp', () {
      final json = TaskReminderDto.fromJson(reminderJson()).toJSON();

      expect(json, {
        'relative_period': 0,
        'relative_to': '',
        'reminder': DateTime.parse(isoDate).toUtc().toIso8601String(),
      });
    });

    test('defaults the relative fields when constructed directly', () {
      final dto = TaskReminderDto(DateTime.utc(2024));

      expect(dto.relativePeriod, 0);
      expect(dto.relativeTo, '');
    });

    test('round-trips through the domain', () {
      final back = TaskReminderDto.fromDomain(
        TaskReminderDto.fromJson({
          'reminder': isoDate,
          'relative_period': -60,
          'relative_to': 'start_date',
        }).toDomain(),
      );

      expect(back.reminder, DateTime.parse(isoDate));
      expect(back.relativePeriod, -60);
      expect(back.relativeTo, 'start_date');
    });
  });

  group('TaskReminder entity', () {
    test('fromJson and toJSON mirror the dto', () {
      final reminder = TaskReminder.fromJson({
        'reminder': isoDate,
        'relative_period': 5,
        'relative_to': 'end_date',
      });

      expect(reminder.relativePeriod, 5);
      expect(reminder.toJSON()['relative_to'], 'end_date');
      expect(
        reminder.toJSON()['reminder'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });
  });
}
