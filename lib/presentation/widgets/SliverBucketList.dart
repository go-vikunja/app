import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/bucket_task_card.dart';

import '../manager/project_store.dart';

class SliverBucketList extends StatelessWidget {
  final Bucket bucket;
  final DragUpdateCallback onTaskDragUpdate;

  const SliverBucketList({
    Key? key,
    required this.bucket,
    required this.onTaskDragUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return index >= bucket.tasks.length
            ? null
            : BucketTaskCard(
                key: ObjectKey(bucket.tasks[index]),
                task: bucket.tasks[index],
                index: index,
                onDragUpdate: onTaskDragUpdate,
                onAccept: (task, index) {
                  _moveTaskToBucket(context, task, index);
                },
              );
      }),
    );
  }

  Future<void> _moveTaskToBucket(
      BuildContext context, Task task, int index) async {
    await Provider.of<ProjectProvider>(context, listen: false).moveTaskToBucket(
      context: context,
      task: task,
      newBucketId: bucket.id,
      index: index,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '\'${task.title}\' was moved to \'${bucket.title}\' successfully!'),
    ));
  }
}
