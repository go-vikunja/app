import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';

class BucketDataSource extends RemoteDataSource {
  BucketDataSource(super.client);

  Future<BucketDto?> add(int projectId, int viewId, BucketDto bucket) {
    return client
        .put('/projects/$projectId/views/$viewId/buckets',
            body: bucket.toJSON())
        .then((response) {
      if (response == null) return null;
      return BucketDto.fromJSON(response.body);
    });
  }

  Future<void> delete(int projectId, int viewId, int bucketId) {
    return client
        .delete('/projects/$projectId/views/$viewId/buckets/$bucketId');
  }

  Future<Response<List<BucketDto>>?> getAllByList(int projectId, int viewId,
      [Map<String, List<String>>? queryParameters]) {
    return client
        .get('/projects/$projectId/views/$viewId/tasks', queryParameters)
        .then((response) => response != null
            ? Response(
                convertList(
                    response.body, (result) => BucketDto.fromJSON(result)),
                response.statusCode,
                response.headers)
            : null);
  }

  Future<BucketDto?> update(int projectId, int viewId, BucketDto bucket) {
    return client
        .post('/projects/$projectId/views/$viewId/buckets/${bucket.id}',
            body: bucket.toJSON())
        .then((response) {
      if (response == null) return null;
      return BucketDto.fromJSON(response.body);
    });
  }

  Future<void> updateTaskBucket(
      int taskId, bucketId, projectId, int viewId) async {
    await client.post(
        '/projects/$projectId/views/$viewId/buckets/$bucketId/tasks',
        body: {
          "task_id": taskId,
          "bucket_id": bucketId,
          "project_view_id": viewId,
          "project_id": projectId
        }).then((response) {});
  }

  Future<void> updateTaskPosition(
      int taskId, int viewId, double position) async {
    await client.post('/tasks/$taskId/position', body: {
      "position": position,
      "project_view_id": viewId,
      "task_id": taskId
    }).then((response) {});
  }
}
