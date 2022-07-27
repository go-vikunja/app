import 'package:flutter/material.dart';
import 'package:vikunja_app/components/BucketTaskCard.dart';
import 'package:vikunja_app/models/bucket.dart';

class SliverBucketList extends StatelessWidget {
  final Bucket bucket;
  final Function onLast;

  const SliverBucketList({Key key, @required this.bucket, this.onLast})
      : assert(bucket != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (bucket.tasks == null) return null;
        return index < bucket.tasks.length
            ? BucketTaskCard(task: bucket.tasks[index])
            : () {
              if (onLast != null) onLast();
              return null;
            }();
      }),
    );
  }
}
