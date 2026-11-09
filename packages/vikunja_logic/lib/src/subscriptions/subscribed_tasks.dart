import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The user's own subscription row on a task, as the app last learnt it
/// from a single read of the task. Vikunja never sends the row itself: a
/// read shows only the subscription that wins, and nothing when the user is
/// not subscribed or has opted out, so the state is pieced together from
/// the read, the task's project and the user's assignment.
enum OwnTaskSubscription {
  /// The user has an own row: the task's reminders reach them whatever
  /// happens to its project or assignees.
  subscribed('subscribed'),

  /// No own row and, as far as the app can tell, no opt-out: the project's
  /// subscription decides, and an assignment made later subscribes the
  /// user, as the server does for an assignee without an own row.
  none('none'),

  /// No own row although the user was an assignee when the task was read:
  /// staying assigned does not change that, so only the project's
  /// subscription decides until the task is read again.
  noneWhileAssigned('none_assigned'),

  /// The user unfollowed the task while its project was followed. The
  /// server keeps this opt-out through assignments and project changes.
  optedOut('opted_out');

  new(this.wireName);

  /// The name in the app's database; the server has none.
  final String wireName;

  /// Null for null and for a name this version does not know.
  static OwnTaskSubscription? fromWire(String? name) =>
      values.where((value) => value.wireName == name).firstOrNull;
}

/// How a single read of a task, or the read after following or unfollowing
/// it, leaves the user's own row. [read] is the task's `subscription`;
/// [projectFollowed] says whether the task's project is followed as far as
/// the device knows, and [assigned] whether the user is one of its
/// assignees as far as the device knows.
///
/// A subscription naming the task is the own row. One naming a project
/// means there is no own row, since an own row would win. Nothing under a
/// followed project can only be an opt-out, which alone hides a project's
/// subscription; nothing under a project that is not followed is taken as
/// no row, because an old opt-out cannot be told apart then.
OwnTaskSubscription ownTaskSubscriptionFrom(
  Subscription? read, {
  required bool projectFollowed,
  required bool assigned,
}) => switch (read?.entity) {
  SubscriptionEntity.task => OwnTaskSubscription.subscribed,
  null when projectFollowed => OwnTaskSubscription.optedOut,
  SubscriptionEntity.project || null =>
    assigned ? OwnTaskSubscription.noneWhileAssigned : OwnTaskSubscription.none,
};

/// The tasks whose reminders and due dates reach the user on a server that
/// sends a task's reminders only to its subscribers (Vikunja 2.8.0 and
/// newer). The server takes the user's own row on the task first, then the
/// row on the task's project, then the nearest parent project's, and an
/// opt-out on the task outranks both.
@immutable
final class SubscribedTasks {
  const new({required this.own, required this.followedProjects});

  /// The user's own row per task id, as recorded from reads of the task;
  /// a task not in it is unknown.
  final Map<int, OwnTaskSubscription> own;

  /// The ids of the projects the user follows, their own subscription or a
  /// parent project's, as the project lists last said.
  final Set<int> followedProjects;

  /// Whether [task] reaches [userId].
  ///
  /// A task created here and not sent yet always does: the user is its
  /// creator. A task not read yet does when the user created it, is one
  /// of its assignees or follows its project, because the server
  /// subscribes creators and assignees on its own, and its upgrade to
  /// 2.8.0 did so for the tasks that existed. Otherwise the stored row
  /// decides, with the task's current project and assignees.
  bool covers(Task task, {required int userId}) {
    if (task.id < 0) return true;
    final assigned = task.assignees.any((user) => user.id == userId);
    final viaProject = followedProjects.contains(task.projectId);
    return switch (own[task.id]) {
      null => task.createdBy?.id == userId || assigned || viaProject,
      OwnTaskSubscription.subscribed => true,
      OwnTaskSubscription.none => viaProject || assigned,
      OwnTaskSubscription.noneWhileAssigned => viaProject,
      OwnTaskSubscription.optedOut => false,
    };
  }
}
