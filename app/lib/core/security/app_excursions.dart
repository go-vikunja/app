import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'app_excursions.g.dart';

/// Round trips the app starts itself (a picker, the camera, the share
/// sheet, the browser sign-in, a system settings page), during which
/// leaving the app does not lock it. Plain Dart, so code that also runs in
/// a background container can use it without the lock controller.
final class AppExcursions {
  new({required this._now});

  /// A longer one counts like a normal hide from its start.
  static const cap = Duration(minutes: 10);

  final DateTime Function() _now;
  final _ended = StreamController<DateTime>.broadcast(sync: true);
  var _running = 0;
  DateTime? _startedAt;
  var _generation = 0;

  bool get active => _running > 0;

  /// When the first of the overlapping ones that still run began.
  DateTime? get startedAt => _startedAt;

  /// The start of each run of overlapping ones, when the last of them ends.
  Stream<DateTime> get ended => _ended.stream;

  Future<T> run<T>(Future<T> Function() action) async {
    final generation = _generation;
    if (_running++ == 0) _startedAt = _now();
    try {
      return await action();
    } finally {
      if (generation == _generation && --_running == 0) {
        final startedAt = _startedAt!;
        _startedAt = null;
        if (!_ended.isClosed) _ended.add(startedAt);
      }
    }
  }

  /// Ends the running ones without waiting for them: after Android
  /// relaunched the activity, a plugin may never answer a call the old one
  /// was waiting on.
  void abandon() {
    _generation++;
    _running = 0;
    _startedAt = null;
  }

  void dispose() => unawaited(_ended.close());
}

@Riverpod(keepAlive: true)
AppExcursions appExcursions(Ref ref) {
  final excursions = AppExcursions(now: ref.watch(clockProvider));
  ref.onDispose(excursions.dispose);
  return excursions;
}
