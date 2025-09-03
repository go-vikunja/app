import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/bucket_data_source.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';

class BucketRepositoryImpl implements BucketRepository {
  final BucketDataSource _dataSource;

  BucketRepositoryImpl(this._dataSource);

  @override
  Future<Bucket?> add(int projectId, int viewId, Bucket bucket) async {
    return (await _dataSource.add(
            projectId, viewId, BucketDto.fromDomain(bucket)))
        ?.toDomain();
  }

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) async {
    return _dataSource.delete(projectId, viewId, bucketId);
  }

  @override
  Future<Response<List<Bucket>>?> getAllByList(int projectId, int viewId,
      [Map<String, List<String>>? queryParameters]) async {
    var response =
        await _dataSource.getAllByList(projectId, viewId, queryParameters);
    return response != null
        ? Response(response.body.map((e) => e.toDomain()).toList(),
            response.statusCode, response.headers)
        : null;
  }

  @override
  Future<Bucket?> update(int projectId, int viewId, Bucket bucket) async {
    return (await _dataSource.update(
            projectId, viewId, BucketDto.fromDomain(bucket)))
        ?.toDomain();
  }

  @override
  Future<void> updateTaskBucket(
      int taskId, bucketId, projectId, int viewId) async {
    return await _dataSource.updateTaskBucket(
        taskId, bucketId, projectId, viewId);
  }

  @override
  Future<void> updateTaskPosition(
      int taskId, int viewId, double position) async {
    return await _dataSource.updateTaskPosition(taskId, viewId, position);
  }
}
