import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';

part 'task_comments_controller.g.dart';

@riverpod
class TaskCommentsController extends _$TaskCommentsController {
  @override
  Future<List<TaskComment>> build(int taskId) async {
    var response = await ref.read(taskCommentRepositoryProvider).getAll(taskId);
    if (response.isSuccessful) {
      return response.toSuccess().body;
    } else if (response.isException) {
      throw Exception(response.toException().message);
    } else {
      throw Exception(response.toError().error);
    }
  }

  Future<void> reload() async {
    var response = await ref.read(taskCommentRepositoryProvider).getAll(taskId);
    if (response.isSuccessful) {
      state = AsyncData(response.toSuccess().body);
    } else if (response.isException) {
      state = AsyncError(
        response.toException().message,
        response.toException().stackTrace,
      );
    } else {
      state = AsyncError(response.toError().error, StackTrace.empty);
    }
  }

  Future<bool> addComment(String text) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final comment = TaskComment(comment: text, author: currentUser);

    final response = await ref
        .read(taskCommentRepositoryProvider)
        .create(taskId, comment);

    if (response.isSuccessful) {
      await reload();
      return true;
    }

    return false;
  }

  Future<bool> updateComment(TaskComment comment, String text) async {
    final updatedComment = TaskComment(
      id: comment.id,
      comment: text,
      author: comment.author,
      created: comment.created,
    );

    final response = await ref
        .read(taskCommentRepositoryProvider)
        .update(taskId, updatedComment);

    if (response.isSuccessful) {
      await reload();
      return true;
    }

    return false;
  }

  Future<bool> deleteComment(int commentId) async {
    final response = await ref
        .read(taskCommentRepositoryProvider)
        .delete(taskId, commentId);

    if (response.isSuccessful) {
      await reload();
      return true;
    }

    return false;
  }
}
