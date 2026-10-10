import 'dart:async';

/// One cached value with a stream that replays it to every new subscriber.
/// An error reaches subscribers only while there is no value, i.e. when the
/// first load fails; later failures are the caller's to report. Events are
/// delivered synchronously, so a load has been seen once its future resolves.
final class CacheEntry<T> {
  T? value;
  final _changes = StreamController<T>.broadcast(sync: true);
  Future<void>? _inFlight;

  bool get isEmpty => value == null;

  bool get isLoading => _inFlight != null;

  bool get hasListener => _changes.hasListener;

  Stream<T> watch() => Stream.multi((subscriber) {
    if (value case final current?) subscriber.add(current);
    final subscription = _changes.stream.listen(
      subscriber.addSync,
      onError: subscriber.addErrorSync,
    );
    subscriber.onCancel = subscription.cancel;
  });

  void set(T next) {
    value = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  /// Forgets the value without telling subscribers; the next load fills it.
  void clear() => value = null;

  void fail(Object error, StackTrace stackTrace) {
    if (!_changes.isClosed) _changes.addError(error, stackTrace);
  }

  /// Runs [load], or joins the run that is still in flight.
  Future<void> loadOnce(Future<void> Function() load) =>
      _inFlight ??= load().whenComplete(() => _inFlight = null);

  void dispose() => _changes.close();
}
