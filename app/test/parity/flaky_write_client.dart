import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The writes of the app that [FlakyWriteClient] can make fail.
enum WriteCall {
  createTask,
  updateTask,
  deleteTask,
  duplicateTask,
  markTaskRead,
  createLabel,
  updateLabel,
  deleteLabel,
  upload,
  deleteAttachment,
  createComment,
  updateComment,
  deleteComment,
  addReaction,
  removeReaction,
}

/// A backend's write client as the app reaches it, failing the same way
/// over the fakes and the server: while [offline] every [WriteCall] fails
/// before it leaves the device, and the next [loseNext] calls of a kind
/// reach the server, which applies them, and lose their answer. [attempts]
/// lists every call, [sent] those that left the device. The other ports
/// pass through unchanged.
final class FlakyWriteClient implements VikunjaWriteClient {
  new(this._real);

  final VikunjaWriteClient _real;
  bool offline = false;
  final Map<WriteCall, int> loseNext = {};
  final List<WriteCall> attempts = [];
  final List<WriteCall> sent = [];

  int sentCount(WriteCall call) => sent.where((sent) => sent == call).length;

  Future<T> _call<T>(WriteCall call, Future<T> Function() send) async {
    attempts.add(call);
    if (offline) {
      throw const NetworkFailure(
        NetworkProblem.unreachable,
        cause: 'connection refused',
      );
    }
    sent.add(call);
    final answer = await send();
    final losing = loseNext[call] ?? 0;
    if (losing > 0) {
      loseNext[call] = losing - 1;
      throw const NetworkFailure(NetworkProblem.timeout);
    }
    return answer;
  }

  @override
  late final TasksWritePort tasks = _FlakyTasks(this, _real.tasks);

  @override
  late final LabelsWritePort labels = _FlakyLabels(this, _real.labels);

  @override
  late final AttachmentsWritePort attachments = _FlakyAttachments(
    this,
    _real.attachments,
  );

  @override
  late final CommentsWritePort comments = _FlakyComments(this, _real.comments);

  @override
  late final ReactionsWritePort reactions = _FlakyReactions(
    this,
    _real.reactions,
  );

  @override
  NotificationsWritePort get notifications => _real.notifications;

  @override
  SubscriptionsWritePort get subscriptions => _real.subscriptions;

  @override
  BucketsWritePort get buckets => _real.buckets;

  @override
  ProjectViewsWritePort get views => _real.views;

  @override
  ProjectsWritePort get projects => _real.projects;

  @override
  SavedFiltersPort get savedFilters => _real.savedFilters;
}

final class _FlakyTasks implements TasksWritePort {
  new(this._client, this._real);

  final FlakyWriteClient _client;
  final TasksWritePort _real;

  @override
  Future<Task> create(NewTask task) =>
      _client._call(WriteCall.createTask, () => _real.create(task));

  @override
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  }) => _client._call(
    WriteCall.updateTask,
    () => _real.update(id, changes, rebaseDescription: rebaseDescription),
  );

  @override
  Future<void> delete(int id) =>
      _client._call(WriteCall.deleteTask, () => _real.delete(id));

  @override
  Future<Task> duplicate(int id) =>
      _client._call(WriteCall.duplicateTask, () => _real.duplicate(id));

  @override
  Future<void> markRead(int id) =>
      _client._call(WriteCall.markTaskRead, () => _real.markRead(id));
}

final class _FlakyLabels implements LabelsWritePort {
  new(this._client, this._real);

  final FlakyWriteClient _client;
  final LabelsWritePort _real;

  @override
  Future<Label> create(NewLabel label) =>
      _client._call(WriteCall.createLabel, () => _real.create(label));

  @override
  Future<Label> update(int id, LabelChanges changes) =>
      _client._call(WriteCall.updateLabel, () => _real.update(id, changes));

  @override
  Future<void> delete(int id) =>
      _client._call(WriteCall.deleteLabel, () => _real.delete(id));
}

final class _FlakyAttachments implements AttachmentsWritePort {
  new(this._client, this._real);

  final FlakyWriteClient _client;
  final AttachmentsWritePort _real;

  @override
  Future<TaskAttachment> upload(
    int taskId, {
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    String? mimeType,
    Duration? timeout,
    CancelToken? cancel,
  }) => _client._call(
    WriteCall.upload,
    () => _real.upload(
      taskId,
      fileName: fileName,
      bytes: bytes,
      length: length,
      mimeType: mimeType,
      timeout: timeout,
      cancel: cancel,
    ),
  );

  @override
  Future<void> delete(int taskId, int attachmentId) => _client._call(
    WriteCall.deleteAttachment,
    () => _real.delete(taskId, attachmentId),
  );
}

final class _FlakyComments implements CommentsWritePort {
  new(this._client, this._real);

  final FlakyWriteClient _client;
  final CommentsWritePort _real;

  @override
  Future<TaskComment> create(int taskId, String html) =>
      _client._call(WriteCall.createComment, () => _real.create(taskId, html));

  @override
  Future<TaskComment> update(int taskId, int commentId, String html) =>
      _client._call(
        WriteCall.updateComment,
        () => _real.update(taskId, commentId, html),
      );

  @override
  Future<void> delete(int taskId, int commentId) => _client._call(
    WriteCall.deleteComment,
    () => _real.delete(taskId, commentId),
  );
}

final class _FlakyReactions implements ReactionsWritePort {
  new(this._client, this._real);

  final FlakyWriteClient _client;
  final ReactionsWritePort _real;

  @override
  Future<void> add(ReactionEntity kind, int id, String value) =>
      _client._call(WriteCall.addReaction, () => _real.add(kind, id, value));

  @override
  Future<void> remove(ReactionEntity kind, int id, String value) => _client
      ._call(WriteCall.removeReaction, () => _real.remove(kind, id, value));
}
