import 'dart:async';

/// One subscription to the stream [_open] makes, shared by every listener
/// while there is one, so a query that several screens watch runs once per
/// change; a listener that joins gets the newest event at once. The
/// subscription ends with the last listener.
///
/// A paused listener gets nothing until it resumes, then the newest value
/// once if it missed any; the subscription is paused while every listener
/// is.
final class SharedLatest<T> {
  new(this._open);

  final Stream<T> Function() _open;
  final _listeners = <_Listener<T>>{};
  StreamSubscription<T>? _upstream;
  var _upstreamPaused = false;
  (T,)? _latest;

  Stream<T> get stream => Stream.multi((controller) {
    final listener = _Listener(controller);
    _listeners.add(listener);
    if (_latest case (final latest,)) controller.add(latest);
    _upstream ??= _open().listen(
      (value) {
        _latest = (value,);
        for (final each in [..._listeners]) {
          each.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        for (final each in [..._listeners]) {
          each.addError(error, stackTrace);
        }
      },
      onDone: () {
        final ended = [..._listeners];
        final latest = _latest;
        _reset();
        for (final each in ended) {
          each.catchUp(latest);
          unawaited(each.controller.close());
        }
      },
    );
    _followListeners();
    controller
      ..onPause = () {
        listener.paused = true;
        _followListeners();
      }
      ..onResume = () {
        listener
          ..paused = false
          ..catchUp(_latest);
        _followListeners();
      }
      ..onCancel = () {
        if (!_listeners.remove(listener)) return null;
        if (_listeners.isNotEmpty) {
          _followListeners();
          return null;
        }
        final cancelled = _upstream?.cancel();
        _reset();
        return cancelled;
      };
  });

  void _followListeners() {
    final upstream = _upstream;
    if (upstream == null) return;
    final pause = _listeners.every((each) => each.paused);
    if (pause == _upstreamPaused) return;
    _upstreamPaused = pause;
    if (pause) {
      upstream.pause();
    } else {
      upstream.resume();
    }
  }

  void _reset() {
    _listeners.clear();
    _upstream = null;
    _upstreamPaused = false;
    _latest = null;
  }
}

final class _Listener<T> {
  new(this.controller);

  final MultiStreamController<T> controller;
  bool paused = false;
  var _missedValue = false;
  (Object, StackTrace)? _missedError;

  void add(T value) {
    if (!paused) return controller.add(value);
    _missedValue = true;
    _missedError = null;
  }

  void addError(Object error, StackTrace stackTrace) {
    if (!paused) return controller.addError(error, stackTrace);
    _missedError = (error, stackTrace);
  }

  void catchUp((T,)? latest) {
    if (latest case (final value,) when _missedValue) controller.add(value);
    if (_missedError case (final error, final stackTrace)) {
      controller.addError(error, stackTrace);
    }
    _missedValue = false;
    _missedError = null;
  }
}

/// The stream [inner] makes for the newest event of [source]; the previous
/// one is cancelled. A pause reaches both.
Stream<T> switchLatest<S, T>(
  Stream<S> source,
  Stream<T> Function(S value) inner,
) => Stream.multi((subscriber) {
  StreamSubscription<T>? current;
  var sourceDone = false;
  var innerDone = true;
  var paused = false;
  final outer = source.listen(
    (value) {
      unawaited(current?.cancel());
      innerDone = false;
      current = inner(value).listen(
        subscriber.add,
        onError: subscriber.addError,
        onDone: () {
          innerDone = true;
          if (sourceDone) unawaited(subscriber.close());
        },
      );
      if (paused) current?.pause();
    },
    onError: subscriber.addError,
    onDone: () {
      sourceDone = true;
      if (innerDone) unawaited(subscriber.close());
    },
  );
  subscriber
    ..onPause = () {
      paused = true;
      outer.pause();
      current?.pause();
    }
    ..onResume = () {
      paused = false;
      outer.resume();
      current?.resume();
    }
    ..onCancel = () async {
      await current?.cancel();
      await outer.cancel();
    };
});
