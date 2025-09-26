import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';

class BucketDataSource extends RemoteDataSource {
  BucketDataSource(super.client);

  Future<Response<BucketDto>> add(int projectId, int viewId, BucketDto bucket) {
    return client.put(
      url: '/projects/$projectId/views/$viewId/buckets',
      body: bucket.toJSON(),
      mapper: (body) {
        return BucketDto.fromJSON(body);
      },
    );
  }

  Future<Response<Object>> delete(
    int projectId,
    int viewId,
    int bucketId,
  ) async {
    return client.delete(
      url: '/projects/$projectId/views/$viewId/buckets/$bucketId',
    );
  }

  Future<Response<List<BucketDto>>> getAllByList(
    int projectId,
    int viewId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return client.get(
      url: '/projects/$projectId/views/$viewId/tasks',
      mapper: (body) {
        return convertList(body, (result) => BucketDto.fromJSON(result));
      },
      queryParameters: queryParameters,
    );
  }

  Future<Response<BucketDto>> update(
    int projectId,
    int viewId,
    BucketDto bucket,
  ) {
    return client.post(
      url: '/projects/$projectId/views/$viewId/buckets/${bucket.id}',
      body: bucket.toJSON(),
      mapper: (body) {
        return BucketDto.fromJSON(body);
      },
    );
  }

  Future<Response<Object>> updateTaskBucket(
    int taskId,
    bucketId,
    projectId,
    int viewId,
  ) async {
    return client.post(
      url: '/projects/$projectId/views/$viewId/buckets/$bucketId/tasks',
      body: {
        "task_id": taskId,
        "bucket_id": bucketId,
        "project_view_id": viewId,
        "project_id": projectId,
      },
    );
  }

  Future<Response<Object>> updateTaskPosition(
    int taskId,
    int viewId,
    double position,
  ) async {
    return client.post(
      url: '/tasks/$taskId/position',
      body: {
        "position": position,
        "project_view_id": viewId,
        "task_id": taskId,
      },
    );
  }
}
