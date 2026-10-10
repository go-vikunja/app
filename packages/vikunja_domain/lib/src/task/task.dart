import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/label/label.dart';
import 'package:vikunja_domain/src/task/task_relation_kind.dart';
import 'package:vikunja_domain/src/task/task_reminder.dart';

/// The web UI's priority scale.
enum TaskPriority {
  unset(0),
  low(1),
  medium(2),
  high(3),
  urgent(4),
  doNow(5);

  new(this.value);

  final int value;

  static TaskPriority fromValue(int value) =>
      values.where((p) => p.value == value).firstOrNull ?? unset;
}

enum RepeatMode {
  /// Every [Task.repeatAfter] after the previous date.
  afterAmount(0),

  /// Monthly, ignoring [Task.repeatAfter].
  monthly(1),

  /// [Task.repeatAfter] counted from the moment the task is marked done.
  fromCurrentDate(2);

  new(this.value);

  final int value;

  static RepeatMode fromValue(int value) =>
      values.where((m) => m.value == value).firstOrNull ?? afterAmount;
}

@immutable
final class Task {
  const new({
    required this.id,
    required this.title,
    required this.projectId,
    this.description = '',
    this.done = false,
    this.doneAt,
    this.dueDate,
    this.startDate,
    this.endDate,
    this.priority = TaskPriority.unset,
    this.percentDone = 0,
    this.hexColor = '',
    this.identifier = '',
    this.index = 0,
    this.isFavorite = false,
    this.position = 0,
    this.labels = const [],
    this.assignees = const [],
    this.reminders = const [],
    this.repeatAfter = Duration.zero,
    this.repeatMode = RepeatMode.afterAmount,
    this.relatedTasks = const {},
    this.bucketId = 0,
    this.createdBy,
    this.created,
    this.updated,
    this.commentCount,
    this.isUnread,
  });

  final int id;
  final String title;
  final int projectId;

  /// HTML.
  final String description;
  final bool done;
  final DateTime? doneAt;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final TaskPriority priority;

  /// 0..1.
  final double percentDone;

  /// Six hex digits without `#`, or empty.
  final String hexColor;

  /// As the server sent it; see [displayIdentifier].
  final String identifier;
  final int index;
  final bool isFavorite;

  /// Position in the view the task was read through; 0 outside a view.
  final double position;
  final List<Label> labels;
  final List<User> assignees;
  final List<TaskReminder> reminders;
  final Duration repeatAfter;
  final RepeatMode repeatMode;

  /// Only the related tasks the user can access; nested tasks carry no
  /// relations of their own.
  final Map<TaskRelationKind, List<Task>> relatedTasks;

  /// Only set when the task was read through a kanban view.
  final int bucketId;
  final User? createdBy;
  final DateTime? created;
  final DateTime? updated;

  /// Only with the matching `expand`.
  final int? commentCount;
  final bool? isUnread;

  /// The web rule: a server identifier of `-<index>` (project without an
  /// identifier prefix) or an empty one is shown as `#<index>`.
  String get displayIdentifier {
    if (identifier.isEmpty || identifier == '-$index') return '#$index';
    return identifier;
  }

  bool get repeats =>
      repeatMode == RepeatMode.monthly || repeatAfter > Duration.zero;

  bool isOverdue(DateTime now) =>
      !done && dueDate != null && !dueDate!.isAfter(now);

  List<Task> get subtasks => relatedTasks[TaskRelationKind.subtask] ?? const [];

  List<Task> get parentTasks =>
      relatedTasks[TaskRelationKind.parentTask] ?? const [];

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.projectId == projectId &&
      other.description == description &&
      other.done == done &&
      other.doneAt == doneAt &&
      other.dueDate == dueDate &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.priority == priority &&
      other.percentDone == percentDone &&
      other.hexColor == hexColor &&
      other.identifier == identifier &&
      other.index == index &&
      other.isFavorite == isFavorite &&
      other.position == position &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    projectId,
    done,
    dueDate,
    priority,
    identifier,
    index,
    position,
    updated,
  );

  @override
  String toString() => 'Task($id, $displayIdentifier, $title)';
}
