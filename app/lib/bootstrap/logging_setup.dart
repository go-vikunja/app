import 'dart:async';
import 'dart:io';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

var _configured = false;
StreamSubscription<LogRecord>? _consoleSink;
StreamSubscription<LogRecord>? _diagnosticsSink;
FlutterExceptionHandler? _flutterErrorBefore;
ErrorCallback? _uncaughtErrorBefore;

final _flutterLog = Logger('Flutter');
final _uncaughtLog = Logger('Uncaught');

/// Debug builds print redacted records to the console; release builds print
/// nothing. In every build the records from WARNING up go to the
/// diagnostics log of [part], which the support details show. Uncaught
/// errors go through the same loggers in every build, redacted. Once per
/// isolate: a background task may run in the app's own isolate.
void configureLogging({
  required AppPart part,
  bool printToConsole = kDebugMode,
  Future<Directory?> Function() diagnosticsDirectory =
      defaultDiagnosticsDirectory,
}) {
  if (_configured) return;
  _configured = true;
  _flutterErrorBefore = FlutterError.onError;
  _uncaughtErrorBefore = PlatformDispatcher.instance.onError;
  // Instead of Flutter's presentError, whose dump prints the exception text
  // unredacted, in release builds too.
  FlutterError.onError = _onFlutterError;
  PlatformDispatcher.instance.onError = _onUncaughtError;
  Logger.root.level = printToConsole ? Level.ALL : Level.WARNING;
  final diagnostics = DiagnosticsLog(
    part: part,
    directory: diagnosticsDirectory,
  );
  useDiagnosticsLog(diagnostics);
  _diagnosticsSink = Logger.root.onRecord.listen(diagnostics.add);
  unawaited(diagnostics.start());
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
  unawaited(_diagnosticsSink?.cancel());
  _consoleSink = null;
  _diagnosticsSink = null;
  useDiagnosticsLog(null);
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
  library: details.library,
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
  String Function() describe, {
  String? library,
}) {
  try {
    String text;
    try {
      text = describe();
    } on Object {
      text = '${error.runtimeType}';
    }
    log.severe(
      UncaughtErrorReport(
        type: error.runtimeType,
        text: redactSecrets(text),
        library: library,
      ),
      null,
      stack,
    );
  } on Object {
    // Nothing left to report it through.
  }
}
