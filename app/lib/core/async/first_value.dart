import 'dart:async';

/// The first value of [stream], or [orElse] when it ends without one; an
/// error before it is the future's.
///
/// Not `Stream.first`: that resolves only after the subscription's cancel
/// future, which a source may never complete, or complete outside the
/// caller's zone, as a replaying stream does.
Future<T> firstValue<T>(Stream<T> stream, {required T orElse}) {
  final completer = Completer<T>();
  late final StreamSubscription<T> subscription;
  subscription = stream.listen(
    (value) {
      if (!completer.isCompleted) completer.complete(value);
      unawaited(subscription.cancel());
    },
    onError: (Object error, StackTrace stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      unawaited(subscription.cancel());
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(orElse);
    },
  );
  return completer.future;
}
