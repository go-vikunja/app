import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/task/task_comments.dart';

class TaskCommentsPage extends StatelessWidget {
  final int taskId;
  final String taskTitle;

  const TaskCommentsPage({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).comments),
            Text(
              taskTitle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TaskComments(taskId: taskId),
      ),
    );
  }
}
