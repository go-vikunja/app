import 'dart:async';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

var _configured = false;
StreamSubscription<LogRecord>? _consoleSink;
FlutterExceptionHandler? _flutterErrorBefore;
ErrorCallback? _uncaughtErrorBefore;

final _flutterLog = Logger('Flutter');
final _uncaughtLog = Logger('Uncaught');

/// Debug builds print redacted records to the console. Release builds keep
/// no log sink until the diagnostics ring buffer exists. Uncaught errors go
/// through the same loggers in every build, redacted. Once per isolate:
/// a background task may run in the app's own isolate.
void configureLogging({bool printToConsole = kDebugMode}) {
  if (_configured) return;
  _configured = true;
  _flutterErrorBefore = FlutterError.onError;
  _uncaughtErrorBefore = PlatformDispatcher.instance.onError;
  // Instead of Flutter's presentError, whose dump prints the exception text
  // unredacted, in release builds too.
  FlutterError.onError = _onFlutterError;
  PlatformDispatcher.instance.onError = _onUncaughtError;
  Logger.root.level = printToConsole ? Level.ALL : Level.OFF;
  if (!printToConsole) return;
  _consoleSink = Logger.root.onRecord.listen((record) {
    final error = record.error;
    debugPrint(
      redactSecrets(
        '${record.level.name} ${record.loggerName}: ${record.message}'
        '${error == null ? '' : ' | $error'}',
      ),
    );
    if (record.stackTrace case final stackTrace?) {
      debugPrintStack(stackTrace: stackTrace, maxFrames: 20);
    }
  });
}

@visibleForTesting
void resetLoggingForTest() {
  // A widget test's binding puts its own handler back after the test.
  if (FlutterError.onError == _onFlutterError) {
    FlutterError.onError = _flutterErrorBefore;
  }
  if (PlatformDispatcher.instance.onError == _onUncaughtError) {
    PlatformDispatcher.instance.onError = _uncaughtErrorBefore;
  }
  unawaited(_consoleSink?.cancel());
  _consoleSink = null;
  _flutterErrorBefore = null;
  _uncaughtErrorBefore = null;
  _configured = false;
  Logger.root.level = Level.INFO;
}

void _onFlutterError(FlutterErrorDetails details) => _logUncaught(
  _flutterLog,
  details.exception,
  details.stack,
  details.exceptionAsString,
);

// True even when logging fails: false, or a throw, makes the engine print
// the error unredacted.
bool _onUncaughtError(Object error, StackTrace stack) {
  _logUncaught(_uncaughtLog, error, stack, () => '$error');
  return true;
}

void _logUncaught(
  Logger log,
  Object error,
  StackTrace? stack,
  String Function() describe,
) {
  try {
    String text;
    try {
      text = describe();
    } on Object {
      text = '${error.runtimeType}';
    }
    log.severe(redactSecrets(text), null, stack);
  } on Object {
    // Nothing left to report it through.
  }
}
