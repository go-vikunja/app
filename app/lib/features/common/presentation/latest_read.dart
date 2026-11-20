import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

/// What a page last read from the server itself, through
/// [LatestReads.readLatest]: the latest read wins, since one that started
/// earlier may miss a change made since. A failure keeps the last value.
final class LatestRead<T> {
  T? _value;
  bool _hasValue = false;
  Object? _failure;
  bool _loading = false;
  int _reads = 0;

  /// Null before the first answer, or when [T] is nullable and that was
  /// the answer; [hasValue] tells the two apart.
  T? get value => _value;

  bool get hasValue => _hasValue;

  /// The failure of the latest read that ended, until a later one answers.
  Object? get failure => _failure;

  /// Until the latest read ends.
  bool get loading => _loading;

  /// For a change made on the page, inside `setState`.
  set value(T value) {
    _value = value;
    _hasValue = true;
  }

  /// For a value that went away, inside `setState`.
  void forget() {
    _value = null;
    _hasValue = false;
  }
}

/// The page's reads into [LatestRead]s. A change made on the page while a
/// read is on its way needs a read after it, else that read's answer can
/// undo the change.
mixin LatestReads<W extends StatefulWidget> on State<W> {
  /// [onValue] and [onFailure] run inside the `setState` that applies the
  /// answer, which a later read or the page's end skip. Every failure is
  /// logged as `Reading [what] failed`.
  Future<void> readLatest<T>(
    LatestRead<T> slot,
    Future<T> Function() read, {
    required Logger log,
    required String what,
    void Function(T value)? onValue,
    void Function(Object error)? onFailure,
  }) async {
    final number = ++slot._reads;
    setState(() => slot._loading = true);
    bool latest() => mounted && number == slot._reads;
    try {
      final value = await read();
      if (latest()) {
        setState(() {
          slot
            ..value = value
            .._failure = null;
          onValue?.call(value);
        });
      }
    } on Object catch (error) {
      log.info('Reading $what failed: ${error.runtimeType}');
      if (latest()) {
        setState(() {
          slot._failure = error;
          onFailure?.call(error);
        });
      }
    } finally {
      if (latest()) setState(() => slot._loading = false);
    }
  }
}
