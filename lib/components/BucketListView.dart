import 'package:flutter/material.dart';
import 'package:vikunja_app/components/BucketTaskCard.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/models/task.dart';

class BucketListView extends StatefulWidget {
  final Bucket bucket;
  final Function onEdit;
  final Function onAddTask;

  const BucketListView({Key key, @required this.bucket, this.onEdit, this.onAddTask})
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
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Text(_currentBucket.title);
          }

          final index = i - 1;

          if (_currentBucket.tasks == null || index >= _currentBucket.tasks.length)
            return null;

          return index < _currentBucket.tasks.length
              ? _buildBucketTaskTile(_currentBucket.tasks[index])
              : null;
        },
      ),
    );
  }

  BucketTaskCard _buildBucketTaskTile(Task task) {
    return BucketTaskCard(
        task: task,
    );
  }
}
