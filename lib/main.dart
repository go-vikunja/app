import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';
import 'package:vikunja_app/constants.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/home.dart';
import 'package:vikunja_app/pages/user/login.dart';
import 'package:vikunja_app/theme/theme.dart';

void main() {
  if (!kReleaseMode) {
    // only log errors in release mode
    _startApp();
    return;
  }
  var sentry = new SentryClient(dsn: SENTRY_DSN);

  FlutterError.onError = (details, {bool forceReport = false}) {
    try {
      sentry.captureException(
        exception: details.exception,
        stackTrace: details.stack,
      );
    } catch (e) {
      print('Sending report to sentry.io failed: $e');
    } finally {
      // Also use Flutter's pretty error logging to the device's console.
      FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    }
  };

  runZoned(
    _startApp,
    onError: (Object error, StackTrace stackTrace) {
      try {
        sentry.captureException(
          exception: error,
          stackTrace: stackTrace,
        );
        print('Error sent to sentry.io: $error');
      } catch (e) {
        print('Sending report to sentry.io failed: $e');
        print('Original error: $error');
      }
    },
  );
}

_startApp() => runApp(VikunjaGlobal(
    child: new VikunjaApp(home: HomePage()),
    login: new VikunjaApp(home: LoginPage())));

class VikunjaApp extends StatelessWidget {
  final Widget home;

  const VikunjaApp({Key key, this.home}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      darkTheme: buildVikunjaDarkTheme(),
      home: this.home,
    );
  }
}
