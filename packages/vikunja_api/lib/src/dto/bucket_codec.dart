import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// `count` is the real total only in a board read and a move answer; the
/// plain bucket list always sends 0.
Bucket parseBucket(Object? json) {
  final map = objectOf(json, 'bucket');
  return Bucket(
    id: requireInt(map, 'id', 'bucket'),
    viewId: requireInt(map, 'project_view_id', 'bucket'),
    title: stringOr(map, 'title', ''),
    position: doubleOr(map, 'position', 0),
    limit: intOr(map, 'limit', 0),
    count: intOr(map, 'count', 0),
  );
}

/// v1 and v2 create and update body. Never an `id` or `project_view_id`:
/// v1 lets those override the URL's.
Map<String, Object?> encodeBucket({
  required String title,
  required int limit,
  double? position,
}) => {'title': title, 'limit': limit, 'position': ?position};

/// The tasks of a bucket in a board read. An empty bucket has no `tasks`
/// key at all.
List<Task> bucketTasksOf(Object? json, {required int bucketId}) =>
    List.unmodifiable(
      objectListOf(objectOf(json, 'bucket')['tasks'])
          .map((task) => parseTask(task).copyWith(bucketId: bucketId)),
    );

/// A move answer: the top-level `bucket_id` is where the task is now (the
/// task in the answer carries 0, and a repeating task moved into the done
/// bucket lands in the default bucket instead of the one asked for); the
/// task is null when it was in that bucket already.
({int bucketId, Task? task}) parseBucketMove(Object? json) {
  final map = objectOf(json, 'bucket move');
  return (
    bucketId: requireInt(map, 'bucket_id', 'bucket move'),
    task: map['task'] == null ? null : parseTask(map['task']),
  );
}
