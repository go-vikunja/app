import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

import 'sync_fakes.dart';

/// Bucket management as the real repository does it, over the boards
/// stored in [tasks] (`FakeTaskRepository.setBoard`) and the views of
/// [projects]: a success changes the stored board and, for the done and
/// default bucket, the view on the board and in the project, like the
/// database would; a view without a stored board takes only the call.
///
/// Every call is recorded in [calls] first: `create 1 5 Title`,
/// `rename 1 5 3 Title`, `setLimit 1 5 3 4`, `move 1 5 3 to 0`,
/// `delete 1 5 3`, `setDoneBucket 1 5 3`, `setDefaultBucket 1 5 null`.
/// [beforeCall] can hold one; [failure], or the entry of [failures] for
/// the method name (`create`, `rename`, …), is thrown instead while set,
/// and nothing changes. Deleting the last bucket fails like the server
/// (`DomainError(412, code: 10003)`); blank titles are `ArgumentError`s.
final class FakeBucketRepository implements BucketRepository {
  new({this.tasks, this.projects});

  final FakeTaskRepository? tasks;
  final FakeProjectRepository? projects;
  final List<String> calls = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String call)? beforeCall;

  /// The id the next created bucket gets.
  int nextBucketId = 900;

  @override
  Future<void> create(int projectId, int viewId, String title) async {
    await _call('create', '$projectId $viewId $title');
    final trimmed = _title(title);
    _change(projectId, viewId, (board) {
      final ordered = [...board.buckets]..sort(compareBucketOrder);
      return (
        buckets: [
          ...ordered,
          Bucket(
            id: nextBucketId++,
            viewId: viewId,
            title: trimmed,
            position: calculateItemPosition(ordered.lastOrNull?.position, null),
          ),
        ],
        snapshot: board.snapshot,
        view: board.view!,
      );
    });
  }

  @override
  Future<void> rename(
    int projectId,
    int viewId,
    int bucketId,
    String title,
  ) async {
    await _call('rename', '$projectId $viewId $bucketId $title');
    final trimmed = _title(title);
    _changeBucket(
      projectId,
      viewId,
      bucketId,
      (bucket) => _copy(bucket, title: trimmed),
    );
  }

  @override
  Future<void> setLimit(
    int projectId,
    int viewId,
    int bucketId,
    int limit,
  ) async {
    await _call('setLimit', '$projectId $viewId $bucketId $limit');
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
    _changeBucket(
      projectId,
      viewId,
      bucketId,
      (bucket) => _copy(bucket, limit: limit),
    );
  }

  @override
  Future<void> move(
    int projectId,
    int viewId,
    int bucketId, {
    required int toIndex,
  }) async {
    await _call('move', '$projectId $viewId $bucketId to $toIndex');
    final stored = _stored(projectId, viewId);
    if (stored == null) return;
    final position = planBucketMove(stored.buckets, bucketId, toIndex);
    if (position == null) return;
    _changeBucket(
      projectId,
      viewId,
      bucketId,
      (bucket) => _copy(bucket, position: position),
    );
  }

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) async {
    await _call('delete', '$projectId $viewId $bucketId');
    final stored = _stored(projectId, viewId);
    if (stored == null) return;
    final view = stored.view!;
    final column = buildBoard(
      view: view,
      buckets: stored.buckets,
      snapshot: stored.snapshot,
      loadedAt: stored.loadedAt,
      projectTasks: stored.projectTasks,
      queued: stored.queued,
      movedHere: stored.movedHere,
      queuedDoneChanges: stored.queuedDoneChanges,
    ).where((column) => column.bucket.id == bucketId).firstOrNull;
    final plan = planBucketDeletion(
      stored.buckets,
      bucketId,
      defaultBucketId: view.defaultBucketId,
      holdsTasks: column != null && columnHoldsTasks(column),
    );
    if (plan == null) {
      if (stored.buckets.length == 1) {
        throw const DomainError(412, code: 10003);
      }
      throw const NotFound(code: 10001);
    }
    final doomed = stored.buckets.firstWhere((b) => b.id == bucketId);
    final target = plan.tasksGoTo;
    _change(projectId, viewId, (board) {
      return (
        buckets: [
          for (final bucket in board.buckets)
            if (bucket.id == target.id)
              _copy(bucket, count: bucket.count + doomed.count)
            else if (bucket.id != bucketId)
              bucket,
        ],
        snapshot: {
          for (final MapEntry(key: taskId, value: slot)
              in board.snapshot.entries)
            taskId: slot.bucketId == bucketId
                ? (bucketId: target.id, position: slot.position)
                : slot,
        },
        view: viewWithBuckets(
          view,
          doneBucketId: view.doneBucketId == bucketId ? 0 : null,
          defaultBucketId: plan.defaultFirst
              ? target.id
              : view.defaultBucketId == bucketId
              ? 0
              : null,
        ),
      );
    });
  }

  @override
  Future<void> setDoneBucket(int projectId, int viewId, int? bucketId) async {
    await _call('setDoneBucket', '$projectId $viewId $bucketId');
    _changeView(
      projectId,
      viewId,
      (view) => viewWithBuckets(view, doneBucketId: bucketId ?? 0),
    );
  }

  @override
  Future<void> setDefaultBucket(
    int projectId,
    int viewId,
    int? bucketId,
  ) async {
    await _call('setDefaultBucket', '$projectId $viewId $bucketId');
    _changeView(
      projectId,
      viewId,
      (view) => viewWithBuckets(view, defaultBucketId: bucketId ?? 0),
    );
  }

  Future<void> _call(String method, String arguments) async {
    final call = '$method $arguments';
    calls.add(call);
    await beforeCall?.call(call);
    if (failures[method] ?? failure case final failure?) throw failure;
  }

  static String _title(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }

  BoardSource? _stored(int projectId, int viewId) {
    final board = tasks?.board(projectId, viewId);
    return board?.view == null ? null : board;
  }

  void _change(
    int projectId,
    int viewId,
    _BoardChange Function(BoardSource board) change,
  ) {
    final tasks = this.tasks;
    final board = _stored(projectId, viewId);
    if (tasks == null || board == null) return;
    final next = change(board);
    tasks.setBoard(
      next.view,
      buckets: [...next.buckets]..sort(compareBucketOrder),
      snapshot: next.snapshot,
      loadedAt: board.loadedAt,
    );
    _replaceProjectView(next.view);
  }

  void _changeBucket(
    int projectId,
    int viewId,
    int bucketId,
    Bucket Function(Bucket bucket) change,
  ) => _change(
    projectId,
    viewId,
    (board) => (
      buckets: [
        for (final bucket in board.buckets)
          if (bucket.id == bucketId) change(bucket) else bucket,
      ],
      snapshot: board.snapshot,
      view: board.view!,
    ),
  );

  void _changeView(
    int projectId,
    int viewId,
    ProjectView Function(ProjectView view) change,
  ) {
    if (_stored(projectId, viewId) != null) {
      _change(
        projectId,
        viewId,
        (board) => (
          buckets: board.buckets,
          snapshot: board.snapshot,
          view: change(board.view!),
        ),
      );
      return;
    }
    final view = projects
        ?.find(projectId)
        ?.views
        .where((view) => view.id == viewId)
        .firstOrNull;
    if (view != null) _replaceProjectView(change(view));
  }

  void _replaceProjectView(ProjectView view) {
    final projects = this.projects;
    if (projects == null) return;
    final project = projects.find(view.projectId);
    if (project == null) return;
    projects.all = [
      for (final candidate in projects.all)
        if (candidate.id == project.id)
          projectWithViews(project, [
            for (final existing in project.views)
              if (existing.id == view.id) view else existing,
          ])
        else
          candidate,
    ];
  }
}

typedef _BoardChange = ({
  List<Bucket> buckets,
  Map<int, BoardSlot> snapshot,
  ProjectView view,
});

/// [view] with the given bucket ids (null keeps one).
ProjectView viewWithBuckets(
  ProjectView view, {
  int? doneBucketId,
  int? defaultBucketId,
}) => ProjectView(
  id: view.id,
  projectId: view.projectId,
  title: view.title,
  kind: view.kind,
  position: view.position,
  filter: view.filter,
  bucketConfigurationMode: view.bucketConfigurationMode,
  defaultBucketId: defaultBucketId ?? view.defaultBucketId,
  doneBucketId: doneBucketId ?? view.doneBucketId,
);

Project projectWithViews(Project project, List<ProjectView> views) => Project(
  id: project.id,
  title: project.title,
  description: project.description,
  identifier: project.identifier,
  hexColor: project.hexColor,
  parentProjectId: project.parentProjectId,
  isArchived: project.isArchived,
  isFavorite: project.isFavorite,
  position: project.position,
  owner: project.owner,
  views: views,
  created: project.created,
  updated: project.updated,
);

Bucket _copy(
  Bucket bucket, {
  String? title,
  int? limit,
  int? count,
  double? position,
}) => Bucket(
  id: bucket.id,
  viewId: bucket.viewId,
  title: title ?? bucket.title,
  limit: limit ?? bucket.limit,
  count: count ?? bucket.count,
  position: position ?? bucket.position,
);
