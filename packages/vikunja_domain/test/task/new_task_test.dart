import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _monday = DateTime.utc(2026, 10, 12, 9);
final _friday = DateTime.utc(2026, 10, 16, 17);

NewTask _task({
  int projectId = 7,
  String title = 'Milk',
  String description = '<p>Oat</p>',
  DateTime? dueDate,
  DateTime? startDate,
  DateTime? endDate,
  TaskPriority priority = TaskPriority.high,
  double percentDone = 0.5,
  String hexColor = 'ff4136',
  Duration repeatAfter = const Duration(days: 30),
  RepeatMode repeatMode = RepeatMode.fromCurrentDate,
  bool isFavorite = true,
}) => NewTask(
  projectId: projectId,
  title: title,
  description: description,
  dueDate: dueDate ?? _monday,
  startDate: startDate ?? _monday,
  endDate: endDate ?? _friday,
  priority: priority,
  percentDone: percentDone,
  hexColor: hexColor,
  repeatAfter: repeatAfter,
  repeatMode: repeatMode,
  isFavorite: isFavorite,
);

void main() {
  group('NewTask', () {
    test('needs only the project and the title', () {
      const task = NewTask(projectId: 7, title: 'Milk');

      expect(task.projectId, 7);
      expect(task.title, 'Milk');
      expect(task.description, '');
      expect(task.dueDate, isNull);
      expect(task.startDate, isNull);
      expect(task.endDate, isNull);
      expect(task.priority, TaskPriority.unset);
      expect(task.percentDone, 0);
      expect(task.hexColor, '');
      expect(task.repeatAfter, Duration.zero);
      expect(task.repeatMode, RepeatMode.afterAmount);
      expect(task.isFavorite, isFalse);
    });

    test('equal field by field', () {
      expect(_task(), _task());
      expect(_task().hashCode, _task().hashCode);
      expect(
        const NewTask(projectId: 7, title: 'Milk'),
        const NewTask(projectId: 7, title: 'Milk'),
      );
    });

    test('differs when any single field differs', () {
      final variants = <String, NewTask>{
        'projectId': _task(projectId: 8),
        'title': _task(title: 'Oat'),
        'description': _task(description: ''),
        'dueDate': _task(dueDate: _friday),
        'startDate': _task(startDate: _friday),
        'endDate': _task(endDate: _monday),
        'priority': _task(priority: TaskPriority.low),
        'percentDone': _task(percentDone: 1),
        'hexColor': _task(hexColor: ''),
        'repeatAfter': _task(repeatAfter: Duration.zero),
        'repeatMode': _task(repeatMode: RepeatMode.monthly),
        'isFavorite': _task(isFavorite: false),
      };

      for (final MapEntry(key: field, value: variant) in variants.entries) {
        expect(variant, isNot(_task()), reason: field);
      }
    });

    test('a set date differs from none', () {
      expect(
        NewTask(projectId: 7, title: 'Milk', dueDate: _monday),
        isNot(const NewTask(projectId: 7, title: 'Milk')),
      );
    });
  });
}
