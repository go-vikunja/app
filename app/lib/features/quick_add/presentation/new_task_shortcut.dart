import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/platform/app_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('NewTaskShortcut');

/// Registers the "New task" shortcut in the device language and opens the
/// New task sheet over the Overview when the app is opened with it, through
/// the [TaskOpener] like a home-screen widget's "+": while the app starts
/// or runs its first sync the shortcut waits; signed out it is dropped.
class NewTaskShortcutListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NewTaskShortcutListener> createState() =>
      _NewTaskShortcutListenerState();
}

class _NewTaskShortcutListenerState
    extends ConsumerState<NewTaskShortcutListener> {
  late final TaskOpener _opener;
  String? _registeredTitle;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
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

  void _quietly(String what, Future<void> Function() action) => unawaited(
    Future.sync(action).catchError((Object error) {
      // Shortcuts are a convenience; without them the app works as before.
      _log.fine('Could not $what the shortcuts: ${error.runtimeType}');
    }),
  );

  void _onAction(String type) {
    if (type != newTaskShortcutType || !mounted) return;
    _opener.requestNewTask();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
