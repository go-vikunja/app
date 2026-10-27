import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/inbox/application/local_task_lookup.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('WidgetLink');

/// Opens what a home-screen widget's link names (see [WidgetLink]), the one
/// that started the app and the ones that arrive while it runs, through the
/// [TaskOpener]: once the shell shows, in the widget's account, which
/// becomes active without asking like a notification's, since a widget
/// only shows the user's own accounts. Links are never logged.
class WidgetLinkListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WidgetLinkListener> createState() => _WidgetLinkListenerState();
}

class _WidgetLinkListenerState extends ConsumerState<WidgetLinkListener> {
  late final TaskOpener _opener;
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
    final source = ref.read(widgetLinkSourceProvider);
    _links = source.links.listen(_onLink);
    unawaited(
      source.initialLink().then(
        (uri) {
          if (uri != null) _onLink(uri);
        },
        onError: (Object error) => _log.fine(
          'Could not read the start widget link: ${error.runtimeType}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    super.dispose();
  }

  void _onLink(Uri uri) {
    if (!mounted) return;
    final link = WidgetLink.parse(uri);
    if (link == null) {
      _log.fine('Ignoring a malformed widget link');
      return;
    }
    if (link case WidgetNewTaskLink(:final accountId, :final projectId)) {
      _opener.requestNewTask(
        accountId: accountId,
        projectId: accountId == null ? null : projectId,
      );
      return;
    }
    _opener.request(
      () => _open(link).catchError((Object error) {
        _log.warning('Could not open a widget link: ${error.runtimeType}');
      }),
    );
  }

  Future<void> _open(WidgetLink link) async {
    switch (link) {
      case WidgetConfigureLink(:final appWidgetId):
        await _showPage(
          AppRoutes.widgetConfigure(appWidgetId, fromWidget: true),
        );
      case WidgetOpenLink(:final accountId?):
        await _opener.activate(accountId);
      case WidgetOpenLink() || WidgetNewTaskLink():
        return;
      case WidgetAccountLink(:final accountId):
        if (await _opener.activate(accountId)) {
          await _goToTab(AppRoutes.account);
        }
      case WidgetTaskLink(:final accountId, :final taskId):
        if (await _opener.activate(accountId)) {
          await _showTask(accountId, taskId);
        }
      case WidgetListLink(:final accountId):
        if (await _opener.activate(accountId)) await _showList(link);
    }
  }

  Future<void> _showTask(String accountId, int taskId) async {
    final task = await _opener.withAccount(
      accountTaskRepositoryProvider(accountId),
      (tasks) => findLocalTask(tasks, taskId),
    );
    if (!mounted || !_opener.isActive(accountId)) return;
    if (task == null) {
      await _opener.showMessage((l10n) => l10n.notificationTaskGone);
      return;
    }
    await _opener.showTask(task);
  }

  Future<void> _showList(WidgetListLink link) => switch (link.kind) {
    WidgetListKind.today ||
    WidgetListKind.overdue => _goToTab(AppRoutes.overview),
    WidgetListKind.upcoming => _goToTab(AppRoutes.upcoming),
    WidgetListKind.favorites => _goToTab(
      AppRoutes.project(Project.favoritesId),
    ),
    WidgetListKind.project => _goToTab(AppRoutes.project(link.id!)),
    WidgetListKind.savedFilter => _goToTab(
      AppRoutes.project(_savedFilterProjectId(link.id!)),
    ),
    WidgetListKind.label => _showPage(AppRoutes.labelTasks(link.id!)),
  };

  /// The filter's pseudo project; a link may carry that already.
  static int _savedFilterProjectId(int id) =>
      id > 0 ? SavedFilter.pseudoProjectIdOf(id) : id;

  /// The dialogs and sheets close, the pages over the shell go as if the
  /// user went back (the edit page asks first), then the tab shows
  /// [location].
  Future<void> _goToTab(String location) async {
    ref.read(rootModalRoutesProvider).closeAll();
    final router = _opener.router;
    if (router.routerDelegate.state.matchedLocation == location) return;
    if (await popPagesOverShell(router) && mounted) router.go(location);
  }

  /// [location] over the shell, unless it shows already.
  Future<void> _showPage(String location) async {
    ref.read(rootModalRoutesProvider).closeAll();
    final router = _opener.router;
    if (router.routerDelegate.state.uri.toString() == location) return;
    unawaited(router.push(location));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
