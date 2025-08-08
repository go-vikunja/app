import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

abstract class BucketRepository {
  Future<Bucket?> add(int projectId, int viewId, Bucket bucket);

  Future delete(int projectId, int viewId, int bucketId);

  Future<Response?> getAllByList(int projectId, int viewId,
      [Map<String, List<String>>? queryParameters]);

  Future<Bucket?> update(int projectId, int viewId, Bucket bucket);
}
