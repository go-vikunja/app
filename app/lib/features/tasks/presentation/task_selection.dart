import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/tasks/presentation/bulk_task_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// Selecting several tasks of a list to act on them at once. Selecting
/// starts with a task's long press or its screen reader action, or with
/// an empty selection from the list's menu; while it lasts a tap selects,
/// [TaskSelectionBar] replaces the app bar and [TaskSelectionActionBar]
/// sits at the bottom. Back, the bar's close button and every action end
/// it. Only tasks the user may change can be selected, which the list
/// decides ([rowSelection]); the count and the actions take only the
/// selected tasks the list shows, so one it hides meanwhile is left out
/// until it shows again.
mixin TaskSelectionActions<W extends ConsumerStatefulWidget>
    on ConsumerState<W> {
  Set<int>? _selected;

  bool get selecting => _selected != null;

  void startSelection([Task? task]) {
    // A snackbar still up, such as the last action's Undo, would cover the
    // bar at the bottom: under a screen reader until it is dismissed.
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() => _selected = {?task?.id});
    Announcer.of(context).say(context.l10n.selectionStarted);
  }

  void endSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
    Announcer.of(context).say(context.l10n.selectionEnded);
  }

  /// The selected ones of [shown], in their order.
  List<Task> selectedAmong(Iterable<Task> shown) {
    final selected = _selected;
    if (selected == null) return const [];
    return [
      for (final task in shown)
        if (selected.contains(task.id)) task,
    ];
  }

  /// How [task]'s row shows while selecting, null otherwise; [changeable]
  /// says whether it can be selected, as the list's Select all counts it.
  TaskRowSelection? rowSelection(Task task, {required bool changeable}) {
    final selected = _selected;
    if (selected == null) return null;
    return TaskRowSelection(
      selected: changeable && selected.contains(task.id),
      onChanged: changeable
          ? (on) => setState(() {
              if (on) {
                selected.add(task.id);
              } else {
                selected.remove(task.id);
              }
            })
          : null,
    );
  }

  /// Selects every one of [tasks], or none when all already are.
  void toggleAll(List<Task> tasks) {
    final selected = _selected;
    if (selected == null) return;
    final ids = {for (final task in tasks) task.id};
    setState(() {
      if (selected.containsAll(ids)) {
        selected.removeAll(ids);
      } else {
        selected.addAll(ids);
      }
    });
  }

  /// Runs a bulk [action] on [tasks]; selecting ends once it wrote.
  Future<void> actOnSelected(
    List<Task> tasks,
    Future<bool> Function(BuildContext context, WidgetRef ref, List<Task> tasks)
    action,
  ) async {
    if (tasks.isEmpty) return;
    final wrote = await action(context, ref, tasks);
    if (wrote && mounted) endSelection();
  }

  /// The app bar while selecting among [selectable], the tasks the list
  /// shows that may be changed.
  PreferredSizeWidget selectionBar(
    List<Task> selectable, {
    PreferredSizeWidget? bottom,
  }) {
    final selected = selectedAmong(selectable);
    return TaskSelectionBar(
      selectedCount: selected.length,
      allSelected:
          selectable.isNotEmpty && selected.length == selectable.length,
      onClose: endSelection,
      onToggleAll: selectable.isEmpty ? null : () => toggleAll(selectable),
      bottom: bottom,
    );
  }

  /// The actions for the selected ones of [selectable].
  Widget selectionActionBar(List<Task> selectable) {
    final selected = selectedAmong(selectable);
    return TaskSelectionActionBar(
      selected: selected,
      onAction: (action) => unawaited(actOnSelected(selected, action)),
    );
  }

  /// [child] with Back ending the selection first, while this screen is the
  /// one in front: an offstage tab, or a page, sheet or dialog over it in
  /// any navigator, leaves Back alone.
  Widget selectionBackHandler({required Widget child}) => _SelectionHoldsBack(
    selecting: selecting,
    child: BackButtonListener(
      onBackButtonPressed: () async {
        if (!selecting || !mounted) return false;
        if (!TickerMode.valuesOf(context).enabled) return false;
        if (!_inFront(context)) return false;
        endSelection();
        return true;
      },
      child: child,
    ),
  );

  /// Whether every route around [context], up through the navigators that
  /// hold one another, is the current one of its navigator.
  static bool _inFront(BuildContext context) {
    BuildContext? at = context;
    while (at != null) {
      if (!(ModalRoute.of(at)?.isCurrent ?? true)) return false;
      at = at.findAncestorStateOfType<NavigatorState>()?.context;
    }
    return true;
  }
}

/// The route of the shell around the tabs, for the lists in the tabs.
/// Android sends Back to the app only while the app says that it handles
/// Back, and on the first tab's first screen only the shell's route can
/// say so: else Back would close the app and leave the selection.
class SelectionBackScope extends InheritedWidget {
  const new({required this.route, required super.child, super.key});

  final ModalRoute<Object?> route;

  @override
  bool updateShouldNotify(SelectionBackScope oldWidget) =>
      route != oldWidget.route;
}

final class _BackHold extends PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
}

/// While the list selects and its tab shows, on Android it holds its own
/// route, so that a predictive back swipe ends the selection instead of
/// popping the list, and the route of [SelectionBackScope]. iOS has no
/// Back to end it with: its edge swipe still pops the list.
class _SelectionHoldsBack extends StatefulWidget {
  const new({required this.selecting, required this.child});

  final bool selecting;
  final Widget child;

  @override
  State<_SelectionHoldsBack> createState() => _SelectionHoldsBackState();
}

class _SelectionHoldsBackState extends State<_SelectionHoldsBack> {
  final _hold = _BackHold();
  var _routes = <ModalRoute<Object?>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final routes = {
      ?ModalRoute.of(context),
      ?context.dependOnInheritedWidgetOfExactType<SelectionBackScope>()?.route,
    };
    for (final route in _routes.difference(routes)) {
      route.unregisterPopEntry(_hold);
    }
    for (final route in routes.difference(_routes)) {
      route.registerPopEntry(_hold);
    }
    _routes = routes;
    _update();
  }

  @override
  void didUpdateWidget(_SelectionHoldsBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  // A hidden tab's selection waits; Back on the first tab must still be
  // able to close the app.
  void _update() => _hold.canPopNotifier.value =
      !widget.selecting || !TickerMode.valuesOf(context).enabled;

  @override
  void dispose() {
    for (final route in _routes) {
      route.unregisterPopEntry(_hold);
    }
    _hold.canPopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The app bar while tasks are selected: close, how many, and Select all
/// (Deselect all once [allSelected]).
class TaskSelectionBar extends StatelessWidget implements PreferredSizeWidget {
  const new({
    required this.selectedCount,
    required this.allSelected,
    required this.onClose,
    required this.onToggleAll,
    this.bottom,
    super.key,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback? onToggleAll;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: l10n.selectionEnd,
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
      title: Semantics(
        liveRegion: true,
        child: Text(l10n.selectionCount(selectedCount)),
      ),
      actions: [
        TextButton(
          onPressed: onToggleAll,
          child: Text(
            allSelected ? l10n.selectionDeselectAll : l10n.selectionSelectAll,
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}

/// The actions for the selected tasks, at the bottom of the screen: Done
/// (Not done when all are done), Due date, Priority, Move and Delete, each
/// an icon over its name; disabled while none is selected.
class TaskSelectionActionBar extends ConsumerWidget {
  const new({required this.selected, required this.onAction, super.key});

  final List<Task> selected;
  final void Function(
    Future<bool> Function(BuildContext context, WidgetRef ref, List<Task> tasks)
    action,
  )
  onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final any = selected.isNotEmpty;
    final allDone = any && selected.every((task) => task.done);
    Widget button(
      IconData icon,
      String label,
      Future<bool> Function(BuildContext, WidgetRef, List<Task>) action,
    ) => Expanded(
      child: _BarButton(
        icon: icon,
        label: label,
        onPressed: any ? () => onAction(action) : null,
      ),
    );
    return Material(
      color: colors.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              button(
                allDone ? Icons.undo : Icons.check,
                allDone ? l10n.selectionMarkNotDone : l10n.selectionMarkDone,
                markTasksDone,
              ),
              button(
                Icons.calendar_today_outlined,
                l10n.taskDetailDueDate,
                (context, ref, tasks) => rescheduleTasks(
                  context,
                  ref,
                  tasks,
                  title: context.l10n.selectionDueDateTitle(tasks.length),
                ),
              ),
              button(
                Icons.flag_outlined,
                l10n.taskDetailPriority,
                setTasksPriority,
              ),
              button(
                Icons.drive_file_move_outlined,
                l10n.selectionMove,
                moveTasks,
              ),
              button(Icons.delete_outline, l10n.selectionDelete, deleteTasks),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const new({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onPressed == null
        ? theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.38)
        : theme.colorScheme.onSecondaryContainer;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
