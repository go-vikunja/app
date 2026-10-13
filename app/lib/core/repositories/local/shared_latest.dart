import 'dart:async';

/// One subscription to the stream [_open] makes, shared by every listener
/// while there is one, so a query that several screens watch runs once per
/// change; a listener that joins gets the newest event at once. The
/// subscription ends with the last listener.
final class SharedLatest<T> {
  new(this._open);

  final Stream<T> Function() _open;
  final _listeners = <MultiStreamController<T>>{};
  StreamSubscription<T>? _upstream;
  (T,)? _latest;

  Stream<T> get stream => Stream.multi((listener) {
    _listeners.add(listener);
    if (_latest case (final latest,)) listener.add(latest);
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
        _reset();
        for (final each in ended) {
          unawaited(each.close());
        }
      },
    );
    listener.onCancel = () {
      if (!_listeners.remove(listener) || _listeners.isNotEmpty) return null;
      final cancelled = _upstream?.cancel();
      _reset();
      return cancelled;
    };
  });

  void _reset() {
    _listeners.clear();
    _upstream = null;
    _latest = null;
  }
}
