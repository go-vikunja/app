import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/task_comment_data_source.dart';
import 'package:vikunja_app/data/models/task_comment_dto.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/domain/repositories/task_comment_repository.dart';

class TaskCommentRepositoryImpl extends TaskCommentRepository {
  final TaskCommentDataSource _dataSource;

  TaskCommentRepositoryImpl(this._dataSource);

  @override
  Future<Response<List<TaskComment>>> getAll(int taskId) async {
    return (await _dataSource.getAll(taskId)).toDomain();
  }

  @override
  Future<Response<TaskComment>> create(int taskId, TaskComment comment) async {
    return (await _dataSource.create(
      taskId,
      TaskCommentDto.fromDomain(comment),
    )).toDomain();
  }

  @override
  Future<Response<TaskComment>> update(int taskId, TaskComment comment) async {
    return (await _dataSource.update(
      taskId,
      TaskCommentDto.fromDomain(comment),
    )).toDomain();
  }

  @override
  Future<Response<Object>> delete(int taskId, int commentId) async {
    return _dataSource.delete(taskId, commentId);
  }
}
