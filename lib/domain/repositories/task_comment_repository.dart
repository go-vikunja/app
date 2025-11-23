import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';

abstract class TaskCommentRepository {
  Future<Response<List<TaskComment>>> getAll(int taskId);
  Future<Response<TaskComment>> create(int taskId, TaskComment comment);
  Future<Response<TaskComment>> update(int taskId, TaskComment comment);
  Future<Response<Object>> delete(int taskId, int commentId);
}
