import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver_providers.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

part 'task_opener.g.dart';

final _log = Logger('TaskOpener');

/// Why a task could not be found or read, as the user reads it.
String taskOpenFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      NotFound(code: 4040) => l10n.taskOpenInTrash,
      NotFound(code: 3018) => l10n.taskOpenProjectInTrash,
      NotFound() => l10n.taskOpenNotFound,
      Forbidden() => l10n.taskOpenForbidden,
      NetworkFailure() => l10n.taskOpenOffline,
      _ => l10n.taskOpenFailed,
    };

/// Opens a task from outside the screens (a notification, a deep link, a
/// home-screen widget, the inbox) the same way: once the router shows the
/// shell, in the task's account, which becomes active first, with the
/// detail in the Overview's pane where the window has room for one, else in
/// a sheet over the Overview or over a page that covers the shell (the edit
/// page keeps its unsaved changes). A detail that opens a task itself shows
/// the next one over or in place of itself and only uses [resolve].
final class TaskOpener {
  new(this._ref) : _router = _ref.read(appRouterProvider) {
    _router.routerDelegate.addListener(_runWhenReady);
  }

  final Ref _ref;
  final GoRouter _router;
  Future<void> Function()? _pending;
  var _running = false;
  var _disposed = false;
  ProviderSubscription<bool>? _unlocks;

  /// How long a switch's registry change may take to reach the providers.
  static const _switchTimeout = Duration(seconds: 10);

  GoRouter get router => _router;

  /// Runs [open] once the router has left the splash, the first sync and
  /// the notification setup, and the app lock is open. One runs at a time;
  /// of the ones that wait, only the last runs. Signed out it is dropped.
  void request(Future<void> Function() open) {
    _pending = open;
    _runWhenReady();
  }

  void _runWhenReady() {
    if (_disposed || _pending == null) return;
    if (_lockedNow()) return;
    final delegate = _router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return;
    final location = delegate.state.matchedLocation;
    if (location == AppRoutes.splash ||
        location == AppRoutes.firstSync ||
        location == AppRoutes.notificationsSetup) {
      return;
    }
    if (_running) return;
    final open = _pending!;
    _pending = null;
    if (!location.startsWith(AppRoutes.home)) return;
    _running = true;
    unawaited(
      open()
          .catchError((Object error) {
            _log.warning('Could not open a task: ${error.runtimeType}');
          })
          .whenComplete(() {
            _running = false;
            _runWhenReady();
          }),
    );
  }

  /// Only once a request waits: a sheet that just resolves tasks needs no
  /// lock controller.
  bool _lockedNow() {
    _unlocks ??= _ref.listen(
      appLockControllerProvider.select((state) => state.locked),
      (_, locked) {
        if (!locked) _runWhenReady();
      },
    );
    return _ref.read(appLockControllerProvider.notifier).isLockedNow();
  }

  /// Makes [accountId] active, and true once the providers follow; false
  /// for an account that is not signed in or a switch that was refused.
  Future<bool> activate(String accountId) async {
    final accounts = _ref.read(accountsProvider).value;
    if (accounts?.find(accountId) == null) return false;
    if (accounts?.activeAccountId != accountId) {
      final switched = await _ref
          .read(accountSwitcherProvider)
          .switchTo(accountId);
      if (!switched || _disposed) return false;
      // The shell closes the previous account's modals and resets the tabs
      // when the registry change reaches the providers; a sheet shown
      // before that would go with them.
      if (!await _awaitActiveAccount(accountId) || _disposed) return false;
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed) return false;
    }
    return _ref.read(activeAccountIdProvider) == accountId;
  }

  /// True once the switch's registry change has reached the providers,
  /// false when it has not within [_switchTimeout].
  Future<bool> _awaitActiveAccount(String accountId) {
    if (_ref.read(activeAccountIdProvider) == accountId) {
      return Future.value(true);
    }
    final completer = Completer<bool>();
    final subscription = _ref.listen(activeAccountIdProvider, (_, next) {
      if (next == accountId && !completer.isCompleted) completer.complete(true);
    });
    return completer.future
        .timeout(_switchTimeout, onTimeout: () => false)
        .whenComplete(subscription.close);
  }

  bool isActive(String accountId) =>
      !_disposed && _ref.read(activeAccountIdProvider) == accountId;

  /// Runs [read] with [provider] kept alive meanwhile. Callers pass the
  /// provider of an account, not the active account's, which may not have
  /// followed a switch yet.
  Future<R> withAccount<T, R>(
    ProviderListenable<T> provider,
    Future<R> Function(T value) read,
  ) async {
    final subscription = _ref.listen(provider, (_, _) {});
    try {
      return await read(subscription.read());
    } finally {
      subscription.close();
    }
  }

  /// The projects [accountId] holds on this device.
  Future<List<Project>> localProjects(String accountId) => withAccount(
    accountProjectRepositoryProvider(accountId),
    (projects) => _firstValue(projects.watchAll()),
  );

  /// The task [reference] names in [accountId]: local first, else online.
  Future<Task> resolve(String accountId, TaskReference reference) =>
      withAccount(
        accountTaskResolverProvider(accountId),
        (resolver) => resolver.resolve(reference),
      );

  /// Shows [task] of the active account at its comment [commentId] when
  /// there is one: the open dialogs and sheets close, a tab other than the
  /// Overview goes back to it, and the task opens anew in the Overview's
  /// pane, or in a sheet where the window has no room for the pane or a
  /// page over the shell stays under it.
  Future<void> showTask(Task task, {int? commentId}) {
    _ref.read(rootModalRoutesProvider).closeAll();
    final location = _router.routerDelegate.state.matchedLocation;
    if (AppRoutes.isTab(location) && location != AppRoutes.overview) {
      _router.go(AppRoutes.overview);
    }
    return showAfterFrame((context) {
      final panes = _ref.read(taskDetailPanesProvider);
      if (panes.showInOverview(task, commentId: commentId)) return;
      unawaited(showTaskDetail(context, task: task, commentId: commentId));
    });
  }

  /// Asks for the New task sheet the way [request] asks for a task: in
  /// [accountId] when given, which becomes active first, with [projectId]
  /// preselected.
  void requestNewTask({String? accountId, int? projectId}) => request(() async {
    if (accountId != null && !await activate(accountId)) return;
    await showNewTask(projectId: projectId);
  });

  /// The New task sheet over the Overview or over a page that covers the
  /// shell, like [showTask]; nothing while one is open, as launching the
  /// app can report the same shortcut twice.
  Future<void> showNewTask({int? projectId}) {
    final modals = _ref.read(rootModalRoutesProvider);
    if (modals.isOpen(newTaskSheetRouteName)) return Future.value();
    modals.closeAll();
    final location = _router.routerDelegate.state.matchedLocation;
    if (AppRoutes.isTab(location) && location != AppRoutes.overview) {
      _router.go(AppRoutes.overview);
    }
    return showAfterFrame((context) {
      if (modals.isOpen(newTaskSheetRouteName)) return;
      unawaited(showNewTaskSheet(context, projectId: projectId));
    });
  }

  Future<void> showMessage(String Function(AppLocalizations l10n) text) =>
      showAfterFrame(
        (context) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text(context.l10n)))),
      );

  /// "Opening the task…" until the returned callback closes it.
  Future<VoidCallback> _showOpening() async {
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? shown;
    await showAfterFrame(
      (context) => shown =
          (ScaffoldMessenger.of(context)..hideCurrentSnackBar()).showSnackBar(
            SnackBar(content: Text(context.l10n.taskOpening), persist: true),
          ),
    );
    return () => shown?.close();
  }

  /// With the root navigator's context, which may not be built yet in the
  /// app's first frames. Completes once [show] ran, so the next opening's
  /// `closeAll` sees what this one opened.
  Future<void> showAfterFrame(
    void Function(BuildContext context) show, {
    int attemptsLeft = 10,
  }) {
    final shown = Completer<void>();
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final navigatorContext =
            _router.routerDelegate.navigatorKey.currentContext;
        if (_disposed || (navigatorContext == null && attemptsLeft == 0)) {
          shown.complete();
        } else if (navigatorContext == null) {
          shown.complete(showAfterFrame(show, attemptsLeft: attemptsLeft - 1));
        } else {
          show(navigatorContext);
          shown.complete();
        }
      })
      ..ensureVisualUpdate();
    return shown.future;
  }

  /// A task in the active account, e.g. from the inbox: resolved, then
  /// shown (at [commentId] when given), or the reason it cannot be.
  Future<void> openInActiveAccount(
    TaskReference reference, {
    int? commentId,
  }) async {
    final accountId = _ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    await _resolveAndShow(accountId, reference, commentId: commentId);
  }

  /// A task of the active account that someone deleted, e.g. from the
  /// inbox on a server with the bin: read from the server even when this
  /// device has it, as its row may not know of the delete yet. A task the
  /// server has opens; one in the bin, or whose project is, says so as for
  /// a link, with Restore where a link has it. When the server cannot be
  /// reached, fails or no longer has the task, [gone] is shown.
  Future<void> openDeletedInActiveAccount(
    int taskId, {
    required String Function(AppLocalizations l10n) gone,
  }) async {
    final accountId = _ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    await _readAndShow(accountId, (opening) async {
      await opening();
      return await withAccount(
        accountServerTaskReadProvider(accountId),
        (read) => read(taskId),
      );
    }, gone: gone);
  }

  /// A link into a task. [TaskDeepLink.account] picks a signed-in account;
  /// otherwise the active account when it has the task on this device,
  /// else the accounts that have it; when none has it, the active account
  /// reads it online. Anyone can make a link, so a switch to another
  /// account is the user's choice, also for a single candidate.
  Future<void> openLink(TaskDeepLink link) async {
    final registry = _ref.read(accountsProvider).value;
    if (registry?.activeAccount == null) return;
    final active = registry!.activeAccountId!;
    final candidates = switch (link.account) {
      final id? when registry.find(id) != null => [registry.find(id)!],
      _ => await _accountsHolding(link.reference, registry),
    };
    final accountId = switch (candidates) {
      [] => active,
      [final only] when only.id == active => active,
      _ => await _pick(candidates),
    };
    if (accountId == null || _disposed) return;
    if (!await activate(accountId)) return;
    await _resolveAndShow(accountId, link.reference);
  }

  /// Says so while the task is read online.
  Future<void> _resolveAndShow(
    String accountId,
    TaskReference reference, {
    int? commentId,
  }) => _readAndShow(
    accountId,
    (opening) =>
        withAccount(accountTaskResolverProvider(accountId), (resolver) async {
          if (await resolver.findLocal(reference) == null) await opening();
          return await resolver.resolve(reference);
        }),
    commentId: commentId,
  );

  /// Shows the task [read] finds, or why it cannot; [read] calls `opening`
  /// before it goes online. With [gone], a network or server failure, or a
  /// task the server does not know, shows [gone] instead.
  Future<void> _readAndShow(
    String accountId,
    Future<Task> Function(Future<void> Function() opening) read, {
    int? commentId,
    String Function(AppLocalizations l10n)? gone,
  }) async {
    VoidCallback? closeOpening;
    final Task task;
    try {
      task = await read(() async {
        if (isActive(accountId)) closeOpening = await _showOpening();
      });
    } on Object catch (error) {
      _log.info('Could not resolve a task: ${error.runtimeType}');
      if (!isActive(accountId)) {
        closeOpening?.call();
      } else if (error
          case NotFound(
            code: 4040,
            trash: TrashDetails(canRestore: true, :final id),
          )
          when _mayRestore(accountId)) {
        await _offerRestore(accountId, id);
      } else if (gone != null && _unknownOrGone(error)) {
        await showMessage(gone);
      } else {
        await showMessage((l10n) => taskOpenFailureText(l10n, error));
      }
      return;
    }
    closeOpening?.call();
    if (!isActive(accountId)) return;
    await showTask(task, commentId: commentId);
  }

  static bool _unknownOrGone(Object error) => switch (error) {
    NotFound(code: 4040 || 3018) => false,
    NotFound() || NetworkFailure() || ServerFailure() => true,
    _ => false,
  };

  /// Not for link-share guests, as on the web, nor where the account's
  /// connection has no bin to restore from: a 2.8.0 server without a
  /// reachable `/api/v2` still answers its codes.
  bool _mayRestore(String accountId) =>
      !_ref.read(accountIsGuestProvider(accountId)) &&
      (_ref
              .read(accountsProvider)
              .value
              ?.find(accountId)
              ?.connection
              .capabilities
              .has(Capability.trash) ??
          false);

  /// "This task is in the bin" with Restore, which brings the task back
  /// and opens it.
  Future<void> _offerRestore(String accountId, int taskId) =>
      showAfterFrame((context) {
        final l10n = context.l10n;
        showDeletedSnackBar(
          ScaffoldMessenger.of(context),
          text: l10n.taskOpenInTrash,
          undoLabel: l10n.trashRestore,
          persist: MediaQuery.accessibleNavigationOf(context),
          onUndo: () => unawaited(_restore(accountId, taskId)),
        );
      });

  Future<void> _restore(String accountId, int taskId) async {
    unawaited(HapticFeedback.selectionClick());
    final Task task;
    try {
      task = await withAccount(
        accountTaskRepositoryProvider(accountId),
        (repository) => repository.restoreTask(taskId),
      );
    } on Object catch (error) {
      _log.info('Could not restore a task: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      await showMessage(
        (l10n) => trashFailureText(l10n, error, TrashAction.restoreTask),
      );
      return;
    }
    if (isActive(accountId)) await showTask(task);
  }

  /// Only the active account when it has the task, else the others that
  /// have it.
  Future<List<RegisteredAccount>> _accountsHolding(
    TaskReference reference,
    AccountRegistryState registry,
  ) async {
    final active = registry.activeAccount!;
    if (await _hasLocally(active.id, reference)) return [active];
    return [
      for (final entry in registry.accountsByRecency)
        if (entry.id != active.id && await _hasLocally(entry.id, reference))
          entry,
    ];
  }

  /// The task's local row, or for an identifier also a local project that
  /// has it: identifiers are unique per server, so that account's resolver
  /// reads the task by index when the row is not here yet.
  Future<bool> _hasLocally(String accountId, TaskReference reference) async {
    try {
      final local = await withAccount(
        accountTaskResolverProvider(accountId),
        (resolver) => resolver.findLocal(reference),
      );
      if (local != null) return true;
      if (reference case TaskByIdentifier(:final identifier)) {
        final wanted = identifier.toLowerCase();
        final projects = await localProjects(accountId);
        return projects.any(
          (project) =>
              !project.isPseudo &&
              project.identifier.isNotEmpty &&
              project.identifier.toLowerCase() == wanted,
        );
      }
      return false;
    } on Object catch (error) {
      _log.fine('Could not look a task up locally: ${error.runtimeType}');
      return false;
    }
  }

  Future<String?> _pick(List<RegisteredAccount> accounts) async {
    final picked = Completer<String?>();
    await showAfterFrame(
      (context) => picked.complete(pickAccount(context, accounts)),
    );
    if (!picked.isCompleted) picked.complete(null);
    return await picked.future;
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _unlocks?.close();
    _router.routerDelegate.removeListener(_runWhenReady);
  }
}

/// Like `Stream.first`, without waiting for the cancel, which a source may
/// never complete (see `findLocalTask`); empty when the stream ends first.
Future<List<T>> _firstValue<T>(Stream<List<T>> stream) {
  final completer = Completer<List<T>>();
  late final StreamSubscription<List<T>> subscription;
  subscription = stream.listen(
    (value) {
      if (!completer.isCompleted) completer.complete(value);
      unawaited(subscription.cancel());
    },
    onError: (Object error, StackTrace stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      unawaited(subscription.cancel());
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(const []);
    },
  );
  return completer.future;
}

/// Reads a task from the server even when this device has it, and stores
/// it the way a task read online for a link is stored. Throws the
/// `VikunjaFailure` of the read, and `NotFound` code 4002 for a task this
/// device is deleting.
typedef ServerTaskRead = Future<Task> Function(int taskId);

@riverpod
ServerTaskRead accountServerTaskRead(Ref ref, String accountId) {
  final db = ref.watch(appDatabaseProvider(accountId));
  final client = ref.watch(readClientProvider(accountId));
  return (taskId) async {
    final task = await client.tasks.read(taskId);
    await db.tasksDao.upsertAll([task]);
    // A row queued for deletion stays hidden through the upsert.
    return await db.tasksDao.find(task.id) ??
        (throw const NotFound(code: 4002));
  };
}

@Riverpod(keepAlive: true)
TaskOpener taskOpener(Ref ref) {
  final opener = TaskOpener(ref);
  ref.onDispose(opener.dispose);
  return opener;
}
