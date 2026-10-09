import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

/// Debug builds print redacted records to the console. Release builds keep
/// no log sink until the diagnostics ring buffer exists.
void configureLogging({bool printToConsole = kDebugMode}) {
  Logger.root.level = printToConsole ? Level.ALL : Level.OFF;
  if (!printToConsole) return;
  Logger.root.onRecord.listen((record) {
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
