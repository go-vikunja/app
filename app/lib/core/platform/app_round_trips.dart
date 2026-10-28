import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

/// The two shapes of the round trips the app starts itself, as excursions
/// that end only once the app is back in the foreground.
extension AppRoundTrips on AppExcursions {
  /// For [action]s that answer when the user is done elsewhere: a picker,
  /// the camera, the share sheet, the browser sign-in. Android hands the
  /// answer over just before the app resumes, so the excursion lasts until
  /// the resume; ending it while the app is still out of sight would count
  /// as a hide and lock at once with "Immediately".
  Future<T> roundTrip<T>(Future<T> Function() action) => run(() async {
    try {
      return await action();
    } finally {
      await _untilForeground();
    }
  });

  /// For [launch]es that only open another screen and answer at once: a
  /// system settings page, "open with", the launcher's pin dialog. The
  /// answer comes back at once; when [opened] says the screen opened, the
  /// excursion lasts until the app has left and is back.
  Future<T> launchAway<T>(
    Future<T> Function() launch, {
    required bool Function(T answer) opened,
  }) {
    final answered = Completer<T>();
    unawaited(
      run(() async {
        final watch = _AwayWatch();
        try {
          final answer = await launch();
          answered.complete(answer);
          if (opened(answer)) await watch.back;
        } on Object catch (error, stack) {
          if (!answered.isCompleted) answered.completeError(error, stack);
        } finally {
          watch.dispose();
        }
      }),
    );
    return answered.future;
  }
}

bool _inForeground() => switch (WidgetsBinding.instance.lifecycleState) {
  null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  _ => false,
};

Future<void> _untilForeground() {
  if (_inForeground()) return Future.value();
  final watch = _AwayWatch(left: true);
  return watch.back.whenComplete(watch.dispose);
}

/// Completes [back] on the first resume after the app left the resumed
/// state; created before the launch, which may hide the app before it
/// answers.
final class _AwayWatch {
  new({this._left = false}) {
    _listener = AppLifecycleListener(onStateChange: _onState);
  }

  late final AppLifecycleListener _listener;
  final _back = Completer<void>();
  bool _left;

  Future<void> get back => _back.future;

  void _onState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _left = true;
    } else if (_left) {
      scheduleMicrotask(_completeIfStillResumed);
    }
  }

  // The resume of an activity Android relaunched under another app's sheet
  // is over within the same lifecycle batch (detached, resumed, inactive).
  void _completeIfStillResumed() {
    if (_back.isCompleted) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _back.complete();
    }
  }

  void dispose() => _listener.dispose();
}
