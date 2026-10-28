import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Has the screen reader say [message], e.g. what a tap changed.
void announce(BuildContext context, String message) =>
    Announcer.of(context).say(message);

/// What [announce] speaks through, taken from a mounted context; taken
/// before an `await`, it still speaks after the screen is gone.
final class Announcer {
  const new _(this._host, this._view, this._direction, this._platformAnnounces);

  factory of(BuildContext context) => Announcer._(
    context.getInheritedWidgetOfExactType<_AnnouncerScope>()?.host,
    View.of(context),
    Directionality.of(context),
    MediaQuery.maybeSupportsAnnounceOf(context) ?? false,
  );

  final _AnnouncerHostState? _host;
  final FlutterView _view;
  final TextDirection _direction;
  final bool _platformAnnounces;

  /// Where the platform cannot announce (always on Android), [message] goes
  /// to the [AnnouncerHost]'s live region instead. With
  /// [onlyIfPlatformAnnounces] it is not spoken there: for an error a text
  /// field's decoration shows, which Material then makes a live region
  /// itself.
  void say(String message, {bool onlyIfPlatformAnnounces = false}) {
    final host = _host;
    if (_platformAnnounces) {
      unawaited(SemanticsService.sendAnnouncement(_view, message, _direction));
    } else if (onlyIfPlatformAnnounces) {
      return;
    } else if (host != null && host.mounted) {
      host._say(message);
    } else {
      unawaited(SemanticsService.sendAnnouncement(_view, message, _direction));
    }
  }
}

/// The polite live region [Announcer.say] speaks through where the platform
/// cannot announce; mounted once above every route and sheet, inside the
/// app lock, which hides it while locked.
class AnnouncerHost extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  /// How long a message stays in the region: one built again later, e.g.
  /// after unlocking, would say it again.
  static const clearAfter = Duration(seconds: 5);

  @override
  State<AnnouncerHost> createState() => _AnnouncerHostState();
}

class _AnnouncerHostState extends State<AnnouncerHost> {
  String _message = '';
  int _said = 0;
  Timer? _clear;

  void _say(String message) {
    _clear?.cancel();
    _clear = Timer(AnnouncerHost.clearAfter, () => _show(''));
    final said = ++_said;
    if (message != _message) {
      _show(message);
      return;
    }
    // An unchanged label is not spoken again: empty for a frame first.
    _show('');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (said == _said) _show(message);
    });
  }

  void _show(String message) {
    if (mounted) setState(() => _message = message);
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AnnouncerScope(
    host: this,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Painted after the routes, so a modal barrier, which blocks only
        // what was painted before it, leaves it in the tree; empty rects
        // are dropped.
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Semantics(
            container: true,
            liveRegion: true,
            accessibilityFocusBlockType: AccessibilityFocusBlockType.blockNode,
            label: _message,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    ),
  );
}

class _AnnouncerScope extends InheritedWidget {
  const new({required this.host, required super.child});

  final _AnnouncerHostState host;

  @override
  bool updateShouldNotify(_AnnouncerScope oldWidget) => false;
}
