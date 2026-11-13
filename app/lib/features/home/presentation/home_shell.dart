import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/pane_split.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tree_column.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler_providers.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/realtime_connection_providers.dart';
import 'package:vikunja_mobile/features/sync/application/startup_sync.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

/// The signed-in app: the tab bar (or, in a wide window, the rail) around
/// the Overview, Upcoming, Projects and Account branches, each tab's task
/// detail pane beside it where the window has room, the project tree's
/// column beside the Projects tab where it has room for that too, the
/// offline banner, the session check when the app opens or resumes,
/// the quiet sync when it opens, the scheduler that keeps syncing while it
/// is in front, the socket that brings the server's notifications at once,
/// the other accounts' outboxes, the notification schedulers
/// of every signed-in account, and the switch from one account to another.
class HomeShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

/// A pane's task waiting for the shell to come to the front, to open as a
/// sheet: the window lost the room for the pane meanwhile.
final class _PendingSheet {
  new({required this.tab, required this.origin, required this.entry});

  final int tab;
  final String origin;
  final TaskDetailPaneEntry entry;
}

class _HomeShellState extends ConsumerState<HomeShell>
    implements TaskDetailPaneShell {
  static const _projectsTab = 2;
  static const _accountTab = 3;
  static const _maxPaneEntries = 10;

  late final AppLifecycleListener _lifecycle;
  late final TaskDetailPanes _panes;

  /// For the one frame after an account switch in which the tabs are left
  /// out.
  var _resettingTabs = false;

  /// Per tab: the tasks opened in its pane, the top one shown, the tab's
  /// location they were opened at, and what had the focus before.
  final List<List<TaskDetailPaneEntry>> _paneStacks = List.generate(
    4,
    (_) => [],
  );
  final _paneOrigins = List<String?>.filled(4, null);
  final _focusBeforePanes = List<FocusNode?>.filled(4, null);
  final _paneFocus = FocusNode(
    debugLabel: 'Task detail pane',
    skipTraversal: true,
  );

  /// Whether the window has room for a pane: two panes and no tabletop.
  bool? _paneMode;
  _PendingSheet? _pendingSheet;
  var _pendingSheetScheduled = false;

  ThemeData? _parentTheme;
  late ThemeData _branchTheme;

  @override
  void initState() {
    super.initState();
    _panes = ref.read(taskDetailPanesProvider)..attach(this);
    _lifecycle = AppLifecycleListener(onResume: _checkSession);
    // A provider nobody listens to is paused; these run while the shell is
    // up. Not in build: every rebuild, a tab switch among them, closes the
    // last build's listeners before it adds its own, which would pause and
    // restart each of them (a new socket, a reset sync timer).
    ref
      ..listenManual(foregroundSyncSchedulerProvider, (_, _) {})
      ..listenManual(realtimeConnectionProvider, (_, _) {})
      ..listenManual(inactiveOutboxesProvider, (_, _) {})
      ..listenManual(accountNotificationSchedulersProvider, (_, _) {})
      ..listenManual(accountWidgetPublishersProvider, (_, _) {})
      ..listenManual(widgetTapImporterProvider, (_, _) {})
      ..listenManual(widgetHostSettingsProvider, (_, _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
      _syncQuietly();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final paneMode =
        WindowLayout.of(context).twoPane &&
        !isTabletop(MediaQuery.displayFeaturesOf(context));
    final before = _paneMode;
    _paneMode = paneMode;
    if (before == null || before == paneMode) return;
    if (paneMode) {
      _returnPendingToPane();
    } else {
      _collapsePanes();
    }
  }

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell's own location: a page over the shell leaves it as it is.
    final tab = _currentTab;
    if (_paneStacks[tab].isNotEmpty && _paneOrigins[tab] != _location) {
      _clearPane(tab);
    }
    if (_pendingSheet case final pending?
        when pending.tab != tab || pending.origin != _location) {
      _pendingSheet = null;
    }
  }

  @override
  void dispose() {
    _panes.detach(this);
    _paneFocus.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  int get _currentTab => widget.navigationShell.currentIndex;

  String get _location =>
      widget.navigationShell.shellRouteContext.routerState.matchedLocation;

  bool get _paneShown =>
      (_paneMode ?? false) &&
      _currentTab != _accountTab &&
      _paneStacks[_currentTab].isNotEmpty;

  void _clearPane(int tab) {
    _paneStacks[tab].clear();
    _paneOrigins[tab] = null;
    _focusBeforePanes[tab] = null;
  }

  void _clearPanes() {
    for (var tab = 0; tab < _paneStacks.length; tab++) {
      _clearPane(tab);
    }
    _pendingSheet = null;
  }

  /// The window lost the room for panes: the current tab's task opens as a
  /// sheet, the other tabs' panes are dropped.
  void _collapsePanes() {
    final tab = _currentTab;
    final stack = _paneStacks[tab];
    final pending = stack.isEmpty
        ? null
        : _PendingSheet(
            tab: tab,
            origin: _paneOrigins[tab]!,
            entry: stack.last,
          );
    _clearPanes();
    _pendingSheet = pending;
  }

  /// The room came back before the pending sheet could open.
  void _returnPendingToPane() {
    final pending = _pendingSheet;
    _pendingSheet = null;
    if (pending == null ||
        pending.tab != _currentTab ||
        pending.origin != _location) {
      return;
    }
    _paneStacks[pending.tab].add(pending.entry);
    _paneOrigins[pending.tab] = pending.origin;
  }

  /// Once the shell is in front, after the pane has left the tree, so the
  /// sheet reads the comment draft the pane kept.
  void _schedulePendingSheet() {
    if (_pendingSheetScheduled) return;
    _pendingSheetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSheetScheduled = false;
      final pending = _pendingSheet;
      if (!mounted || pending == null || (_paneMode ?? false)) return;
      if (!(ModalRoute.isCurrentOf(context) ?? false)) return;
      _pendingSheet = null;
      unawaited(
        showTaskDetail(
          Navigator.of(context).context,
          task: pending.entry.task,
          board: pending.entry.board,
        ),
      );
    });
  }

  bool _inPane(FocusNode? node) =>
      node != null &&
      (node == _paneFocus || node.ancestors.contains(_paneFocus));

  bool _inTab(FocusNode? node) {
    final tab = _tabNavigator?.focusNode;
    return node != null &&
        tab != null &&
        (node == tab || node.ancestors.contains(tab));
  }

  void _showPane(
    int tab,
    void Function(List<TaskDetailPaneEntry> stack) change,
  ) {
    final stack = _paneStacks[tab];
    // A close returns the focus to the row last used to open a task.
    final focus = FocusManager.instance.primaryFocus;
    if (stack.isEmpty || _inTab(focus)) _focusBeforePanes[tab] = focus;
    setState(() => change(stack));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _paneFocus.context != null) _paneFocus.requestFocus();
    });
  }

  void _replacePane(int tab, TaskDetailPaneEntry entry) =>
      _showPane(tab, (stack) {
        stack
          ..clear()
          ..add(entry);
        _paneOrigins[tab] = _location;
      });

  /// The id of [entry]'s task now: a queued create's row takes the
  /// server's id once it is sent.
  int _currentIdOf(TaskDetailPaneEntry entry) =>
      ref.read(taskByIdProvider(entry.task.id)).value?.id ?? entry.task.id;

  /// [board] is the board of the card it came from; the same task on top
  /// takes it over, without opening anew.
  void _openFromList(Task task, {TaskBoardOrigin? board}) {
    final tab = _currentTab;
    final top = _paneStacks[tab].lastOrNull;
    if (top != null && _currentIdOf(top) == task.id) {
      if (top.board != board) setState(() => top.board = board);
      return;
    }
    _replacePane(tab, TaskDetailPaneEntry(task, board: board));
  }

  void _pushPane(int tab, Task task) => _showPane(tab, (stack) {
    stack.add(TaskDetailPaneEntry(task));
    if (stack.length > _maxPaneEntries) stack.removeAt(0);
  });

  /// The task before, or no pane after the first.
  void _popPane(int tab) {
    final stack = _paneStacks[tab];
    if (stack.length > 1) {
      _showPane(tab, (stack) => stack.removeLast());
    } else {
      _closePane(tab);
    }
  }

  /// [taskId] was deleted in [tab]'s pane: it leaves every tab's pane, and
  /// a pane with nothing left closes.
  void _dropDeleted(int tab, int taskId) {
    final ids = {taskId, ?_paneStacks[tab].lastOrNull?.task.id};
    void drop(List<TaskDetailPaneEntry> stack) {
      stack.removeWhere((entry) => ids.contains(entry.task.id));
      // Else back would show the same task once more.
      for (var index = stack.length - 1; index > 0; index--) {
        if (stack[index].task.id == stack[index - 1].task.id) {
          stack.removeAt(index - 1);
        }
      }
    }

    setState(() {
      for (var other = 0; other < _paneStacks.length; other++) {
        if (other == tab) continue;
        drop(_paneStacks[other]);
        if (_paneStacks[other].isEmpty) _clearPane(other);
      }
    });
    if (_paneStacks[tab].every((entry) => ids.contains(entry.task.id))) {
      _closePane(tab);
    } else {
      _showPane(tab, drop);
    }
  }

  void _closePane(int tab) {
    if (_paneStacks[tab].isEmpty) return;
    final before = _focusBeforePanes[tab];
    final focusInPane = _inPane(FocusManager.instance.primaryFocus);
    setState(() => _clearPane(tab));
    // A row's node is gone once the row has scrolled out of the list's
    // cache, though it keeps its context.
    if (before != null &&
        !_inPane(before) &&
        (before.context?.mounted ?? false) &&
        before.canRequestFocus) {
      before.requestFocus();
    } else if (focusInPane) {
      _tabNavigator?.focusNode.requestFocus();
    }
  }

  TaskDetailPaneHost _paneHost(int tab) {
    final stack = _paneStacks[tab];
    final previous = stack.length > 1 ? stack[stack.length - 2] : null;
    return TaskDetailPaneHost(
      close: () => _closePane(tab),
      openOther: (task) => _pushPane(tab, task),
      deleted: (taskId) => _dropDeleted(tab, taskId),
      back: previous == null ? null : () => _popPane(tab),
      // A related task may have come with its id alone.
      backTitle: previous == null
          ? null
          : ref.watch(taskByIdProvider(previous.task.id)).value?.title ??
                previous.task.title,
    );
  }

  NavigatorState? get _tabNavigator =>
      widget.navigationShell.shellRouteContext.navigatorKey.currentState;

  @override
  bool showInOverview(Task task, {int? commentId}) {
    if (!mounted) return false;
    // The newer task opens, in the pane or as a sheet.
    _pendingSheet = null;
    if (!(_paneMode ?? false) ||
        _currentTab != 0 ||
        !(ModalRoute.isCurrentOf(context) ?? false)) {
      return false;
    }
    _replacePane(0, TaskDetailPaneEntry(task, commentId: commentId));
    return true;
  }

  /// Back inside the pane before the tab's own pages: unless something is
  /// open over the shell or in the tab (a menu), it returns to the task
  /// before or closes the pane.
  Future<bool> _paneBack() async {
    if (!mounted || !_paneShown) return false;
    if (!(ModalRoute.isCurrentOf(context) ?? false)) return false;
    final tabNavigator = _tabNavigator;
    if (tabNavigator != null &&
        ref.read(rootModalRoutesProvider).isOpenOn(tabNavigator)) {
      return false;
    }
    _popPane(_currentTab);
    return true;
  }

  /// Android's predictive back claims a back swipe on a tab's page even in
  /// a tab that is not shown, or under a page or sheet over the shell, and
  /// pops it there; the swipe then pops nothing that is seen, or two things
  /// at once. Without it, the swipe goes through the same path as the back
  /// button, which asks what is in front first. Taps look as before.
  ThemeData _branchThemeOf(ThemeData parent) {
    if (identical(parent, _parentTheme)) return _branchTheme;
    _parentTheme = parent;
    return _branchTheme = parent.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...parent.pageTransitionsTheme.builders,
          TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  void _checkSession() {
    if (!mounted || ref.read(signOutControllerProvider)) return;
    if (ref.read(signInControllerProvider) is SignInInProgress) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null) return;
    unawaited(ref.read(sessionCheckProvider).check(entry));
  }

  void _syncQuietly() {
    if (!mounted || ref.read(signOutControllerProvider)) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    // A session that ended cannot sync; the Account tab asks to sign in.
    if (entry == null || entry.account.needsReauth) return;
    unawaited(
      ref.read(startupSyncProvider).run(ref.read(syncEngineProvider(entry.id))),
    );
  }

  void _onSignInChanged(SignInState? previous, SignInState next) {
    if (next is SignInFailed) unawaited(HapticFeedback.heavyImpact());
  }

  void _onActiveAccountChanged(String? previous, String? next) {
    // A failure card belongs to the account it happened for.
    ref.read(signInControllerProvider.notifier).reset();
    if (previous != null && next != null) {
      _closePreviousAccount();
    } else {
      setState(_clearPanes);
    }
    _checkSession();
    _syncQuietly();
  }

  /// Runs before the next frame, so no screen of the previous account is
  /// built with the new account's data: dialogs and sheets close without
  /// an exit animation, pages over the shell go (blank while they animate
  /// out), and every tab starts at its root. A tab's navigator keeps its
  /// stack and the shell each tab's last location; leaving them out of
  /// one frame disposes both.
  void _closePreviousAccount() {
    ref.read(rootModalRoutesProvider).closeAll();
    GoRouter.of(context).go(AppRoutes.overview);
    setState(() {
      _clearPanes();
      _resettingTabs = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _resettingTabs = false);
    });
  }

  void _onSignOutChanged(bool? previous, bool next) {
    // Another account may have become active meanwhile.
    if (previous == true && !next) {
      _checkSession();
      _syncQuietly();
    }
  }

  void _selectTab(int index) {
    // Re-selecting the current tab returns to its first screen, without a
    // pane.
    final again = index == _currentTab;
    if (again) _closePane(index);
    widget.navigationShell.goBranch(index, initialLocation: again);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(signInControllerProvider, _onSignInChanged)
      ..listen<String?>(
        accountsProvider.select((accounts) => accounts.value?.activeAccountId),
        _onActiveAccountChanged,
      )
      ..listen(signOutControllerProvider, _onSignOutChanged);
    final signedIn = ref.watch(
      accountsProvider.select(
        (accounts) => accounts.value?.activeAccount != null,
      ),
    );
    // Briefly false while this route animates out after signing out.
    if (!signedIn) return const Scaffold();

    final l10n = context.l10n;
    final signingOut = ref.watch(signOutControllerProvider);
    final signingIn = ref.watch(signInControllerProvider) is SignInInProgress;
    final onFirstTab = widget.navigationShell.currentIndex == 0;

    final destinations = [
      AdaptiveDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.tabOverview,
      ),
      AdaptiveDestination(
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: l10n.tabUpcoming,
      ),
      AdaptiveDestination(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        label: l10n.tabProjects,
      ),
      AdaptiveDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l10n.tabAccount,
      ),
    ];
    final rail = usesNavigationRail(context);
    final offline = ref.watch(offlineProvider.select((state) => state != null));
    final tab = _currentTab;
    final paneShown = _paneShown;
    // A dependency, so the shell rebuilds when it is in front again.
    final inFront = ModalRoute.isCurrentOf(context) ?? false;
    if (_pendingSheet != null && inFront) _schedulePendingSheet();
    final top = paneShown ? _paneStacks[tab].last : null;
    // A link-share guest has one project, and a fold would cut a column.
    final guest = ref.watch(activeAccountIsGuestProvider);
    final treeBeside =
        (_paneMode ?? false) &&
        !guest &&
        WindowLayout.of(context).threePane(besideRail: rail) &&
        !hasVerticalFold(MediaQuery.displayFeaturesOf(context));
    final treeColumn = treeBeside && tab == _projectsTab && !_resettingTabs
        ? ProjectTreeColumn(selectedId: AppRoutes.projectIdIn(_location))
        : null;
    final tabs = TaskDetailPaneScope(
      available: (_paneMode ?? false) && tab != _accountTab,
      selectedTaskId: top == null
          ? null
          : ref.watch(
                  taskByIdProvider(top.task.id)
                      .select((task) => task.value?.id),
                ) ??
                top.task.id,
      open: _openFromList,
      child: ProjectTreeColumnScope(
        shown: treeBeside,
        child: Theme(
          data: _branchThemeOf(Theme.of(context)),
          child: _resettingTabs
              ? const SizedBox.expand()
              : widget.navigationShell,
        ),
      ),
    );
    final pane = top != null
        ? TaskDetailPane(
            entry: top,
            host: _paneHost(tab),
            focusNode: _paneFocus,
          )
        : null;
    final content = Builder(
      // Below the scaffold, whose bar takes the bottom inset.
      builder: (context) {
        // The rail takes the inset on its side, the banner the one below.
        final ltr = Directionality.of(context) == TextDirection.ltr;
        final padding = MediaQuery.of(context)
            .removePadding(removeLeft: rail && ltr, removeRight: rail && !ltr);
        return Column(
          children: [
            Expanded(
              child: MediaQuery(
                data: padding.removePadding(removeBottom: offline),
                child: OfflineBannerArea(
                  // Always this row, so opening or closing a pane or the
                  // tree's column keeps the tabs' state.
                  child: LayoutBuilder(
                    builder: (context, constraints) => _TabsBesidePane(
                      contentWidth: constraints.maxWidth,
                      treeColumn: treeColumn,
                      tabs: tabs,
                      pane: pane,
                    ),
                  ),
                ),
              ),
            ),
            MediaQuery(data: padding, child: const OfflineBanner()),
          ],
        );
      },
    );

    // On Android before 12, back on the root route finishes the activity and
    // with it the isolate, which would cut off a token exchange or sign-out.
    // Back on another tab's root returns to the first tab instead, as Android
    // expects; a tab's own stack is popped before a pop reaches the shell,
    // and an open pane before both.
    return PopScope(
      canPop: !signingIn && !signingOut && onFirstTab && !paneShown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !signingIn && !signingOut && !onFirstTab) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: BackButtonListener(
        onBackButtonPressed: _paneBack,
        // The same structure with the rail as with the bar, so a rotation
        // keeps the content, the banner among it, which screen readers would
        // otherwise announce again. The rail is outside the scaffold, whose
        // snackbars then stay beside it rather than across it.
        child: Row(
          children: [
            if (rail)
              AdaptiveNavigationRail(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _selectTab,
                destinations: destinations,
              ),
            Expanded(
              child: Scaffold(
                body: content,
                bottomNavigationBar: rail
                    ? null
                    : AdaptiveNavigationBar(
                        selectedIndex: widget.navigationShell.currentIndex,
                        onDestinationSelected: _selectTab,
                        destinations: destinations,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tabs, beside them on their end side the pane with its divider (or
/// the fold it is split on), and on their start side the project tree's
/// column with its divider. Each keeps clear of the inset on the others'
/// sides, and is a region of its own for screen readers and keyboards
/// while the pane or the column shows: up to three regions. The pane's
/// width comes from the whole content, as without the column.
class _TabsBesidePane extends StatelessWidget {
  const new({
    required this.contentWidth,
    required this.treeColumn,
    required this.tabs,
    required this.pane,
  });

  final double contentWidth;
  final Widget? treeColumn;
  final Widget tabs;
  final Widget? pane;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final pane = this.pane;
    final treeColumn = this.treeColumn;
    final split = pane == null
        ? null
        : paneSplitFor(
            windowWidth: media.size.width,
            contentWidth: contentWidth,
            textDirection: Directionality.of(context),
            displayFeatures: media.displayFeatures,
          );
    final hasColumn = treeColumn != null;
    final hasPane = split != null;
    final regions = hasPane || hasColumn;
    // Keyed: where both ends of the row change at once, as between the
    // Projects tab's column and another tab's pane, a Row builds its
    // unkeyed children in between anew, the tabs' region among them.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (treeColumn != null) ...[
          SizedBox(
            key: const ValueKey('tree column'),
            width: ProjectTreeColumn.width,
            child: MediaQuery(
              data: media.removePadding(removeLeft: !ltr, removeRight: ltr),
              child: treeColumn,
            ),
          ),
          const VerticalDivider(
            key: ValueKey('tree divider'),
            width: 1,
            thickness: 1,
          ),
        ],
        Expanded(
          key: const ValueKey('tabs'),
          child: MediaQuery(
            data: media.removePadding(
              removeLeft: ltr ? hasColumn : hasPane,
              removeRight: ltr ? hasPane : hasColumn,
            ),
            child: Semantics(
              container: regions,
              explicitChildNodes: regions,
              child: FocusTraversalGroup(child: tabs),
            ),
          ),
        ),
        if (split != null && pane != null) ...[
          if (split.divider)
            const VerticalDivider(
              key: ValueKey('pane divider'),
              width: 1,
              thickness: 1,
            )
          else
            SizedBox(key: const ValueKey('pane gap'), width: split.gap),
          SizedBox(
            key: const ValueKey('pane'),
            width: split.paneWidth,
            child: MediaQuery(
              data: media.removePadding(removeLeft: ltr, removeRight: !ltr),
              child: pane,
            ),
          ),
        ],
      ],
    );
  }
}
