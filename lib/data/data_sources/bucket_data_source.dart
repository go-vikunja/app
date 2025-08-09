import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';

class BucketDataSource extends RemoteDataSource {
  BucketDataSource(Client client) : super(client);

  Future<BucketDto?> add(int projectId, int viewId, BucketDto bucket) {
    return client
        .put('/projects/$projectId/views/$viewId/buckets',
            body: bucket.toJSON())
        .then((response) {
      if (response == null) return null;
      return BucketDto.fromJSON(response.body);
    });
  }

  Future delete(int projectId, int viewId, int bucketId) {
    return client
        .delete('/projects/$projectId/views/$viewId/buckets/$bucketId');
  }

  Future<Response<List<BucketDto>>?> getAllByList(int projectId, int viewId,
      [Map<String, List<String>>? queryParameters]) {
    return client
        .get('/projects/$projectId/views/$viewId/tasks', queryParameters)
        .then((response) => response != null
            ? new Response(
                convertList(
                    response.body, (result) => BucketDto.fromJSON(result)),
                response.statusCode,
                response.headers)
            : null);
  }

  // TODO: implement maxPages
  int get maxPages => maxPages;

  Future<BucketDto?> update(int projectId, int viewId, BucketDto bucket) {
    return client
        .post('/projects/$projectId/views/$viewId/buckets/${bucket.id}',
            body: bucket.toJSON())
        .then((response) {
      if (response == null) return null;
      return BucketDto.fromJSON(response.body);
    });
  }
}
