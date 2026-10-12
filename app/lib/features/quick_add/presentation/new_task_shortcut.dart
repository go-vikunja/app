import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/platform/app_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';

final _log = Logger('NewTaskShortcut');

/// Registers the "New task" shortcut in the device language and opens the
/// New task sheet over the Overview when the app is opened with it. While
/// the app starts or runs its first sync the shortcut waits; signed out it
/// is dropped.
class NewTaskShortcutListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NewTaskShortcutListener> createState() =>
      _NewTaskShortcutListenerState();
}

class _NewTaskShortcutListenerState
    extends ConsumerState<NewTaskShortcutListener> {
  late final GoRouter _router;
  String? _registeredTitle;
  bool _pending = false;
  bool _opening = false;
  Future<void>? _shownSheet;

  static const List<String> _tabs = [
    AppRoutes.overview,
    AppRoutes.projects,
    AppRoutes.account,
  ];

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider)
      ..routerDelegate.addListener(_onRouteChanged);
    _quietly(
      'initialize',
      () => ref.read(appShortcutsProvider).initialize(_onAction),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final title = context.l10n.newTask;
    if (title == _registeredTitle) return;
    _registeredTitle = title;
    _quietly(
      'register',
      () => ref.read(appShortcutsProvider).setNewTaskShortcut(title),
    );
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _quietly(String what, Future<void> Function() action) => unawaited(
    Future.sync(action).catchError((Object error) {
      // Shortcuts are a convenience; without them the app works as before.
      _log.fine('Could not $what the shortcuts: ${error.runtimeType}');
    }),
  );

  bool get _sheetOpen =>
      ref.read(rootModalRoutesProvider).isOpen(newTaskSheetRouteName);

  void _onAction(String type) {
    if (type != newTaskShortcutType || !mounted) return;
    _pending = true;
    _openWhenReady();
  }

  void _onRouteChanged() {
    if (_pending) _openWhenReady();
  }

  void _openWhenReady() {
    final delegate = _router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return;
    final location = delegate.state.matchedLocation;
    if (location == AppRoutes.splash || location == AppRoutes.firstSync) {
      return;
    }
    _pending = false;
    if (!location.startsWith(AppRoutes.home)) return;
    // Launching the app can report the same shortcut twice.
    if (_opening || _shownSheet != null || _sheetOpen) return;
    _opening = true;
    ref.read(rootModalRoutesProvider).closeAll();
    // A page over the shell (the edit page) stays; the sheet opens over it.
    if (_tabs.any(location.startsWith) && location != AppRoutes.overview) {
      _router.go(AppRoutes.overview);
    }
    _showAfterFrame();
  }

  void _showAfterFrame({int attemptsLeft = 10}) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final navigatorContext =
            _router.routerDelegate.navigatorKey.currentContext;
        // The navigator may not be built yet in the app's first frames.
        if (navigatorContext == null && attemptsLeft > 0) {
          _showAfterFrame(attemptsLeft: attemptsLeft - 1);
          return;
        }
        _opening = false;
        if (navigatorContext == null || _sheetOpen) return;
        _shownSheet = showNewTaskSheet(navigatorContext)
            .whenComplete(() => _shownSheet = null);
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
