import 'dart:async';

/// Timers a test fires by hand, in place of `Timer.new`.
final class FakeTimers {
  final List<FakeTimer> scheduled = [];

  Timer create(Duration duration, void Function() callback) {
    final timer = FakeTimer(duration, callback);
    scheduled.add(timer);
    return timer;
  }

  List<FakeTimer> get active => [
    for (final timer in scheduled)
      if (timer.isActive) timer,
  ];

  /// The wait of the only pending timer.
  Duration get pendingWait => active.single.duration;

  void fireNext() => active.first.fire();
}

final class FakeTimer implements Timer {
  new(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}
