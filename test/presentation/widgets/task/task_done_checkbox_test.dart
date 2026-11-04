import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/presentation/widgets/task/task_done_checkbox.dart';

void main() {
  Task buildTask({bool done = false, bool loading = false}) {
    final task = Task(
      id: 1,
      title: 'Task',
      createdBy: User(username: 'user'),
      projectId: 1,
      done: done,
    );
    task.loading = loading;
    return task;
  }

  testWidgets('shows a checkbox when the task is not loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDoneCheckbox(task: buildTask(), onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a spinner while the task is loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDoneCheckbox(
            task: buildTask(loading: true),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });
}
