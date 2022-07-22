import 'package:flutter/material.dart';
import 'package:vikunja_app/components/BucketTaskCard.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/models/task.dart';

class BucketListView extends StatefulWidget {
  final Bucket bucket;
  final Function onAddTask;

  const BucketListView({Key key, @required this.bucket, this.onAddTask})
      : assert(bucket != null),
        super(key: key);

  @override
  State<BucketListView> createState() => _BucketListViewState(this.bucket);
}

class _BucketListViewState extends State<BucketListView> {
  Bucket _currentBucket;

  _BucketListViewState(this._currentBucket)
      : assert(_currentBucket != null);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (context, i) {
        if (_currentBucket.tasks == null || i >= _currentBucket.tasks.length) {
          if (i == 0 || i == _currentBucket.tasks?.length)
            return TextButton.icon(
              onPressed: widget.onAddTask,
              label: Text('Add Task'),
              icon: Icon(Icons.add),
            );
          return null;
        }

        return i < _currentBucket.tasks.length
            ? _buildBucketTaskTile(_currentBucket.tasks[i])
            : null;
      },
    );
  }

  BucketTaskCard _buildBucketTaskTile(Task task) {
    return BucketTaskCard(
        task: task,
    );
  }
}
