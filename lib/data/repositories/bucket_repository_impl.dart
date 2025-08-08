import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/bucket_datasource.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';

class BucketRepositoryImpl implements BucketRepository {
  BucketDataSource _dataSource;

  BucketRepositoryImpl(this._dataSource);

  @override
  Future<Bucket?> add(int projectId, int viewId, Bucket bucket) async {
    return (await _dataSource.add(
            projectId, viewId, BucketDto.fromDomain(bucket)))
        ?.toDomain();
  }

  @override
  Future delete(int projectId, int viewId, int bucketId) async {
    return _dataSource.delete(projectId, viewId, bucketId);
  }

  Future<Response?> getAllByList(int projectId, int viewId,
      [Map<String, List<String>>? queryParameters]) async {
    return _dataSource.getAllByList(projectId, viewId, queryParameters);
  }

  @override
  Future<Bucket?> update(int projectId, int viewId, Bucket bucket) async {
    return (await _dataSource.update(
            projectId, viewId, BucketDto.fromDomain(bucket)))
        ?.toDomain();
  }
}
