import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/widget_task.dart';
import 'package:vikunja_app/domain/entities/widget_view.dart';

void main() {
  group('WidgetView.fromString', () {
    test('maps each known value onto its view', () {
      expect(WidgetView.fromString('inbox'), WidgetView.inbox);
      expect(WidgetView.fromString('upcoming'), WidgetView.upcoming);
      expect(WidgetView.fromString('project'), WidgetView.project);
      expect(WidgetView.fromString('today'), WidgetView.today);
    });

    test('falls back to today for anything unrecognised', () {
      expect(WidgetView.fromString(''), WidgetView.today);
      expect(WidgetView.fromString('nonsense'), WidgetView.today);
    });
  });

  group('WidgetView.displayName', () {
    test('names every view', () {
      expect(WidgetView.inbox.displayName, 'Inbox');
      expect(WidgetView.today.displayName, 'Today');
      expect(WidgetView.upcoming.displayName, 'Upcoming');
      expect(WidgetView.project.displayName, 'Project');
    });
  });

  group('WidgetTask.toJSON', () {
    test('encodes the due date as epoch milliseconds in utc', () {
      final due = DateTime.utc(2024, 3, 14, 15, 9);
      final json = WidgetTask(
        id: '7',
        title: 'Ship it',
        dueDate: due,
        today: true,
      ).toJSON();

      expect(json, {
        'id': '7',
        'title': 'Ship it',
        'dueDate': due.millisecondsSinceEpoch,
        'today': true,
      });
    });

    test('encodes a missing due date as null and applies defaults', () {
      expect(WidgetTask().toJSON(), {
        'id': '0',
        'title': 'None',
        'dueDate': null,
        'today': false,
      });
    });
  });
}
