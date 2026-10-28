import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

part 'task_detail_pane.g.dart';

/// A task in a tab's detail pane. The pane keeps a stack of them, the tasks
/// opened from one another inside it, and shows the top one.
final class TaskDetailPaneEntry {
  new(this.task, {this.commentId});

  final Task task;

  /// The comment to show, handed over when the entry first shows.
  int? commentId;

  /// How far its detail was scrolled, for coming back to it.
  double scrollOffset = 0;
}

/// Above the screens inside the shell's tabs, and only there: whether a
/// task opens in the current tab's pane now ([available]), which task that
/// pane shows ([selectedTaskId]), and [open] to show one in it. Pages over
/// the shell, sheets, dialogs and the pane itself do not find it.
class TaskDetailPaneScope extends InheritedModel<int> {
  const new({
    required this.available,
    required this.selectedTaskId,
    required this.open,
    required super.child,
    super.key,
  });

  final bool available;
  final int? selectedTaskId;
  final void Function(Task task) open;

  /// The task the current tab's pane shows; null without a pane and
  /// outside the tabs. Rebuilds [context] whenever that changes.
  static int? selectedTaskIdOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TaskDetailPaneScope>()
      ?.selectedTaskId;

  /// Whether the current tab's pane shows the task [taskId]; rebuilds
  /// [context] only when that answer changes.
  static bool isSelected(BuildContext context, int taskId) =>
      InheritedModel.inheritFrom<TaskDetailPaneScope>(
        context,
        aspect: taskId,
      )?.selectedTaskId ==
      taskId;

  @override
  bool updateShouldNotify(TaskDetailPaneScope oldWidget) =>
      available != oldWidget.available ||
      selectedTaskId != oldWidget.selectedTaskId;

  @override
  bool updateShouldNotifyDependent(
    TaskDetailPaneScope oldWidget,
    Set<int> dependencies,
  ) =>
      selectedTaskId != oldWidget.selectedTaskId &&
      (dependencies.contains(selectedTaskId) ||
          dependencies.contains(oldWidget.selectedTaskId));
}

/// The detail of [task] for a row, a card or a timeline bar: in the
/// current tab's pane when the window has room for one, else in a sheet.
void openTaskDetail(BuildContext context, {required Task task}) {
  final scope = context.getInheritedWidgetOfExactType<TaskDetailPaneScope>();
  if (scope != null && scope.available) {
    scope.open(task);
  } else {
    unawaited(showTaskDetail(context, task: task));
  }
}

/// The shell, as far as opening a task from outside the screens goes.
abstract interface class TaskDetailPaneShell {
  /// Shows [task], at its comment [commentId] when given, as the only task
  /// of the Overview's pane; false, and nothing shown, unless the window
  /// has room for the pane, the Overview is in front and nothing covers
  /// the shell.
  bool showInOverview(Task task, {int? commentId});
}

/// The shell that is up, for the task opener, which shows from above it;
/// the one attached last while a new one replaces the old.
final class TaskDetailPanes {
  final _shells = <TaskDetailPaneShell>[];

  void attach(TaskDetailPaneShell shell) => _shells.add(shell);

  void detach(TaskDetailPaneShell shell) => _shells.remove(shell);

  bool showInOverview(Task task, {int? commentId}) =>
      _shells.lastOrNull?.showInOverview(task, commentId: commentId) ?? false;
}

@Riverpod(keepAlive: true)
TaskDetailPanes taskDetailPanes(Ref ref) => TaskDetailPanes();

/// The detail of [entry]'s task beside the list: on the page's colour,
/// below the status bar, a region of its own for screen readers and
/// keyboards. [focusNode] takes the focus when a task opens in it; the
/// first Tab from there reaches the header.
class TaskDetailPane extends StatelessWidget {
  const new({
    required this.entry,
    required this.host,
    required this.focusNode,
    super.key,
  });

  final TaskDetailPaneEntry entry;
  final TaskDetailPaneHost host;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      // The header is pinned, so the pane keeps clear of the status bar
      // itself.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: FocusTraversalGroup(
            child: Focus(
              focusNode: focusNode,
              // A node of its own would take in the header's identifier and
              // read it with the whole pane outlined, before the back arrow.
              includeSemantics: false,
              child: _PaneEntry(
                key: ObjectKey(entry),
                entry: entry,
                host: host,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One entry's detail, which a back to it builds anew at its offset.
class _PaneEntry extends StatefulWidget {
  const new({required this.entry, required this.host, super.key});

  final TaskDetailPaneEntry entry;
  final TaskDetailPaneHost host;

  @override
  State<_PaneEntry> createState() => _PaneEntryState();
}

class _PaneEntryState extends State<_PaneEntry> {
  late final ScrollController _scroll;
  late final int? _commentId;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _commentId = entry.commentId;
    entry.commentId = null;
    // Not from the page's storage, which every entry would share.
    _scroll = ScrollController(
      initialScrollOffset: entry.scrollOffset,
      keepScrollOffset: false,
    )..addListener(_keepOffset);
  }

  // The list is detached before this State is disposed.
  void _keepOffset() => widget.entry.scrollOffset = _scroll.offset;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TaskDetailSheet(
    task: widget.entry.task,
    scrollController: _scroll,
    commentId: _commentId,
    pane: widget.host,
  );
}
