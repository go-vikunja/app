import 'package:meta/meta.dart';

/// Where a task goes on one kanban view: into [bucketId], at [position]
/// within it, or wherever the server keeps it when [position] is null.
@immutable
final class BucketPlacement {
  const new({required this.bucketId, this.position});

  final int bucketId;
  final double? position;

  @override
  bool operator ==(Object other) =>
      other is BucketPlacement &&
      other.bucketId == bucketId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(bucketId, position);

  @override
  String toString() => 'BucketPlacement($bucketId, $position)';
}
