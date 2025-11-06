import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    var textColor = _getTextColor(context);
    var bgColor = _getBackgroundColor(context);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.identifier,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: textColor),
                  ),
                ),
                if (task.done)
                  Badge(label: Text("Done"), backgroundColor: Colors.green),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ),
                if (task.hasDueDate) DueDateCard(task.dueDate!),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (task.priority != null && task.priority! > 1)
                    PriorityBatch(task.priority!),
                ],
              ),
            ),
            if (task.labels.isNotEmpty)
              Wrap(
                spacing: 4,
                children: task.labels
                    .map((e) => LabelWidget(label: e))
                    .toList(),
              ),
            if (task.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.notes),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTextColor(BuildContext context) =>
      _getBackgroundColor(context).computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;

  Color _getBackgroundColor(BuildContext context) {
    return task.color != Colors.black && task.color != null
        ? task.color!
        : Theme.of(context).colorScheme.surface;
  }
}
