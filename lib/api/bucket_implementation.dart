import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/service/services.dart';

class BucketAPIService extends APIService implements BucketService {
  BucketAPIService(Client client) : super(client);

  @override
  Future<Bucket?> add(int projectId, Bucket bucket) {
    return client
        .put('/projects/$projectId/buckets', body: bucket.toJSON())
        .then((response) {
          if (response == null) return null;
          return Bucket.fromJSON(response.body);
        });
  }

  @override
  Future delete(int projectId, int bucketId) {
    return client
        .delete('/projects/$projectId/buckets/$bucketId');
  }

  /* Not implemented in the Vikunja API
  @override
  Future<Bucket> get(int listId, int bucketId) {
    return client
        .get('/lists/$listId/buckets/$bucketId')
        .then((response) => Bucket.fromJSON(response.body));
  }
  */

  @override
  Future<Response?> getAllByList(int projectId,
      [Map<String, List<String>>? queryParameters]) {
    return client
        .get('/projects/$projectId/buckets', queryParameters)
        .then((response) => response != null ? new Response(
            convertList(response.body, (result) => Bucket.fromJSON(result)),
            response.statusCode,
            response.headers
        ) : null);
  }

  @override
  // TODO: implement maxPages
  int get maxPages => maxPages;

  @override
  Future<Bucket?> update(Bucket bucket) {
    return client
        .post('/projects/${bucket.projectId}/buckets/${bucket.id}', body: bucket.toJSON())
        .then((response) {
          if (response == null) return null;
          return Bucket.fromJSON(response.body);
        });
  }
}