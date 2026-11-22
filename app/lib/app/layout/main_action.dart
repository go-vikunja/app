import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/large_text.dart';

/// What a screen offers as its main action, such as New task.
@immutable
final class MainAction {
  const new({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// The main actions of the screens in the shell's tabs while the navigation
/// rail shows: the rail offers [action], the one of the screen in front, and
/// the screens show no floating button of their own.
class RailMainActions extends ChangeNotifier {
  final _claims = <Object, MainAction>{};
  var _notifying = false;
  var _disposed = false;

  /// Of the screen that claimed it last and still holds it.
  MainAction? get action => _claims.values.lastOrNull;

  /// The action of the screen in front when the rail's button is tapped.
  void press() => action?.onPressed();

  /// Null where the screens keep their floating buttons.
  static RailMainActions? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_RailMainActionsScope>()
      ?.actions;

  /// For the screens in [child]; [actions] null leaves them their floating
  /// buttons. Always in the tree, so a resize keeps the screens' state.
  static Widget scope({
    required RailMainActions? actions,
    required Widget child,
  }) => _RailMainActionsScope(actions: actions, child: child);

  void _claim(Object screen, MainAction? action) {
    final before = this.action;
    if (action == null) {
      _claims.remove(screen);
    } else {
      _claims[screen] = action;
    }
    final after = this.action;
    if (before?.icon != after?.icon || before?.label != after?.label) {
      _notifyAfterFrame();
    }
  }

  // Screens claim while they build or go away, when the rail cannot build.
  void _notifyAfterFrame() {
    if (_notifying) return;
    _notifying = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _notifying = false;
        if (!_disposed) notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _RailMainActionsScope extends InheritedWidget {
  const new({required this.actions, required super.child});

  final RailMainActions? actions;

  @override
  bool updateShouldNotify(_RailMainActionsScope oldWidget) =>
      actions != oldWidget.actions;
}

/// Around a screen with a main action: beside the shell's navigation rail
/// ([RailMainActions]) the rail shows [action] while the screen is in front
/// (its tab shown, its page on top), and the screen leaves out its own
/// floating button ([MainActionButton.unlessBesideRail]).
class MainActionClaim extends StatefulWidget {
  const new({required this.action, required this.child, super.key});

  final MainAction? action;
  final Widget child;

  @override
  State<MainActionClaim> createState() => _MainActionClaimState();
}

class _MainActionClaimState extends State<MainActionClaim> {
  RailMainActions? _rail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _claim();
  }

  @override
  void didUpdateWidget(MainActionClaim oldWidget) {
    super.didUpdateWidget(oldWidget);
    _claim();
  }

  @override
  void dispose() {
    _rail?._claim(this, null);
    super.dispose();
  }

  void _claim() {
    final rail = RailMainActions.maybeOf(context);
    if (rail != _rail) {
      _rail?._claim(this, null);
      _rail = rail;
    }
    // A hidden tab's tickers stop, and so do those of a page once another
    // page covers it; a menu or sheet over the screen leaves them running.
    final inFront = TickerMode.valuesOf(context).enabled;
    rail?._claim(this, inFront ? widget.action : null);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A screen's floating button for [action]: extended with its label, and
/// from 1.5 times the text size only its icon, as the label would then
/// cover a good part of the rows the user reads.
class MainActionButton extends StatelessWidget {
  const new({required this.action, super.key});

  final MainAction action;

  /// For the scaffold of a screen in a [MainActionClaim]: null without
  /// [action] and beside the navigation rail, which offers it instead.
  static Widget? unlessBesideRail(BuildContext context, MainAction? action) =>
      action == null || RailMainActions.maybeOf(context) != null
      ? null
      : MainActionButton(action: action);

  @override
  Widget build(BuildContext context) => largeTextOf(context)
      ? FloatingActionButton(
          // A page over the shell finds the heroes of every tab's top route.
          heroTag: null,
          tooltip: action.label,
          onPressed: action.onPressed,
          child: Icon(action.icon),
        )
      : FloatingActionButton.extended(
          heroTag: null,
          onPressed: action.onPressed,
          icon: Icon(action.icon),
          label: Text(action.label),
        );
}

/// The navigation rail's button for the main action of the screen in
/// front, in a slot that keeps its size without one, so the destinations
/// below it stay where they are.
class RailMainActionButton extends StatelessWidget {
  const new({required this.actions, super.key});

  final RailMainActions actions;

  static const size = 56.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ListenableBuilder(
      listenable: actions,
      builder: (context, _) => switch (actions.action) {
        final action? => FloatingActionButton(
          heroTag: null,
          elevation: 0,
          tooltip: action.label,
          onPressed: actions.press,
          child: Icon(action.icon),
        ),
        null => const SizedBox.shrink(),
      },
    ),
  );
}
