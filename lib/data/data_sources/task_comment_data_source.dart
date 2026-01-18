import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/task_comment_dto.dart';

class TaskCommentDataSource extends RemoteDataSource {
  TaskCommentDataSource(super.client);

  Future<Response<List<TaskCommentDto>>> getAll(int taskId) {
    return client.get(
      url: '/tasks/$taskId/comments',
      mapper: (body) {
        return convertList(body, (result) => TaskCommentDto.fromJson(result));
      },
    );
  }

  Future<Response<TaskCommentDto>> create(int taskId, TaskCommentDto comment) {
    return client.put(
      url: '/tasks/$taskId/comments',
      body: comment.toJSON(),
      mapper: (body) => TaskCommentDto.fromJson(body),
    );
  }

  Future<Response<TaskCommentDto>> update(int taskId, TaskCommentDto comment) {
    return client.post(
      url: '/tasks/$taskId/comments/${comment.id}',
      body: comment.toJSON(),
      mapper: (body) => TaskCommentDto.fromJson(body),
    );
  }

  Future<Response<Object>> delete(int taskId, int commentId) {
    return client.delete(url: '/tasks/$taskId/comments/$commentId');
  }
}
