import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

void main() {
  setUpAll(loadTimeZones);

  test('5,000 tasks evaluate well under 150 ms', () {
    final random = Random(24);
    final now = utc('2026-10-20T08:05:00Z');
    final tasks = [
      for (var id = 1; id <= 5000; id++)
        FilterableTask(
          id: id,
          projectId: 1 + random.nextInt(40),
          index: id,
          title: 'Task $id ${random.nextBool() ? 'report' : 'plan'}',
          description: '<p>Some description of task $id with <b>markup</b></p>',
          done: random.nextInt(4) == 0,
          priority: random.nextInt(6),
          percentDone: random.nextInt(11) / 10,
          dueDate: random.nextBool()
              ? now.add(Duration(hours: random.nextInt(24 * 60) - 24 * 30))
              : null,
          labelIds: {
            for (var i = random.nextInt(4); i > 0; i--) random.nextInt(30),
          },
          assigneeUsernames: {
            for (var i = random.nextInt(3); i > 0; i--)
              'user${random.nextInt(8)}',
          },
          reminders: [
            for (var i = random.nextInt(3); i > 0; i--)
              now.add(Duration(hours: random.nextInt(24 * 30))),
          ],
          createdByUsername: 'user${random.nextInt(8)}',
        ),
    ];
    const filter =
        'done = false && (due_date < now/d+7d || priority >= 4) && '
        'labels in 1, 2, 3, 4, 5 || assignees = user1 && title like report || '
        'reminders > now && reminders < now+3d && percent_done < 0.5';
    final context = FilterContext(
      now: now,
      location: zone('Europe/Berlin'),
      includeNulls: true,
    );

    final stopwatch = Stopwatch()..start();
    final expression = parsed(filter);
    final bound = expression.bind(context);
    final cold = tasks.where(bound.matches).length;
    final coldTime = stopwatch.elapsedMicroseconds;

    var warmTime = 0;
    for (var round = 0; round < 10; round++) {
      stopwatch.reset();
      final count = tasks
          .where((task) => matchesFilter(expression, task, context))
          .length;
      warmTime += stopwatch.elapsedMicroseconds;
      expect(count, cold);
    }

    // ignore: avoid_print, the step's report quotes these numbers.
    print(
      'filter over ${tasks.length} tasks: $cold match; parse, bind and the '
      'first pass ${(coldTime / 1000).toStringAsFixed(1)} ms, then '
      '${(warmTime / 10000).toStringAsFixed(1)} ms per pass',
    );
    expect(coldTime, lessThan(150000));
    expect(cold, greaterThan(0));
  });
}
