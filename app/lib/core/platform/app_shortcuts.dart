import 'package:quick_actions/quick_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_shortcuts.g.dart';

const newTaskShortcutType = 'new_task';

/// The home screen shortcuts: Android app shortcuts, iOS quick actions.
abstract interface class AppShortcuts {
  /// [onAction] gets the type of a shortcut the app was opened with, also
  /// for the one that launched it.
  Future<void> initialize(void Function(String type) onAction);

  Future<void> setNewTaskShortcut(String localizedTitle);
}

final class QuickActionsAppShortcuts implements AppShortcuts {
  const new([this._quickActions = const QuickActions()]);

  final QuickActions _quickActions;

  @override
  Future<void> initialize(void Function(String type) onAction) =>
      _quickActions.initialize(onAction);

  @override
  Future<void> setNewTaskShortcut(String localizedTitle) =>
      _quickActions.setShortcutItems([
        ShortcutItem(
          type: newTaskShortcutType,
          localizedTitle: localizedTitle,
          // A drawable on Android, an image set on iOS.
          icon: 'shortcut_new_task',
        ),
      ]);
}

@Riverpod(keepAlive: true)
AppShortcuts appShortcuts(Ref ref) => const QuickActionsAppShortcuts();
