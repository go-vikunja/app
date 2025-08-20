import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

abstract class BucketRepository {
  Future<Bucket?> add(int projectId, int viewId, Bucket bucket);

  Future<void> delete(int projectId, int viewId, int bucketId);

  Future<Response<List<Bucket>>?> getAllByList(
    int projectId,
    int viewId, [
    Map<String, List<String>>? queryParameters,
  ]);

  Future<Bucket?> update(int projectId, int viewId, Bucket bucket);

  Future<void> updateTaskBucket(int taskId, bucketId, projectId, int viewId);

  Future<void> updateTaskPosition(int taskId, int viewId, double position);
}
