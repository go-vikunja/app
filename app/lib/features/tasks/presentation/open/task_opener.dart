import 'dart:async';

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
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

part 'task_opener.g.dart';

final _log = Logger('TaskOpener');

/// Why a task could not be found or read, as the user reads it.
String taskOpenFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      NotFound() => l10n.taskOpenNotFound,
      Forbidden() => l10n.taskOpenForbidden,
      NetworkFailure() => l10n.taskOpenOffline,
      _ => l10n.taskOpenFailed,
    };

/// Opens a task from outside the screens (a notification, a deep link, a
/// home-screen widget, the inbox) the same way: once the router shows the
/// shell, in the task's account, which becomes active first, with the
/// detail sheet over the Overview or over a page that covers the shell (the
/// edit page keeps its unsaved changes). A sheet that opens a task itself
/// stacks the next one instead and only uses [resolve].
final class TaskOpener {
  new(this._ref) : _router = _ref.read(appRouterProvider) {
    _router.routerDelegate.addListener(_runWhenReady);
  }

  final Ref _ref;
  final GoRouter _router;
  Future<void> Function()? _pending;
  var _running = false;
  var _disposed = false;

  /// How long a switch's registry change may take to reach the providers.
  static const _switchTimeout = Duration(seconds: 10);

  GoRouter get router => _router;

  /// Runs [open] once the router has left the splash, the first sync and
  /// the notification setup. One runs at a time; of the ones that wait,
  /// only the last runs. Signed out it is dropped.
  void request(Future<void> Function() open) {
    _pending = open;
    _runWhenReady();
  }

  void _runWhenReady() {
    if (_disposed || _pending == null) return;
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

  /// Shows [task] of the active account in a new detail sheet, at its
  /// comment [commentId] when there is one: the open dialogs and sheets
  /// close, a tab other than the Overview goes back to it, a page over the
  /// shell stays under the sheet.
  Future<void> showTask(Task task, {int? commentId}) {
    _ref.read(rootModalRoutesProvider).closeAll();
    final location = _router.routerDelegate.state.matchedLocation;
    if (AppRoutes.isTab(location) && location != AppRoutes.overview) {
      _router.go(AppRoutes.overview);
    }
    return showAfterFrame(
      (context) =>
          unawaited(showTaskDetail(context, task: task, commentId: commentId)),
    );
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
  }) async {
    VoidCallback? closeOpening;
    final Task task;
    try {
      task = await withAccount(accountTaskResolverProvider(accountId), (
        resolver,
      ) async {
        if (await resolver.findLocal(reference) == null &&
            isActive(accountId)) {
          closeOpening = await _showOpening();
        }
        return await resolver.resolve(reference);
      });
    } on Object catch (error) {
      _log.info('Could not resolve a task: ${error.runtimeType}');
      if (isActive(accountId)) {
        await showMessage((l10n) => taskOpenFailureText(l10n, error));
      } else {
        closeOpening?.call();
      }
      return;
    }
    closeOpening?.call();
    if (!isActive(accountId)) return;
    await showTask(task, commentId: commentId);
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

@Riverpod(keepAlive: true)
TaskOpener taskOpener(Ref ref) {
  final opener = TaskOpener(ref);
  ref.onDispose(opener.dispose);
  return opener;
}
