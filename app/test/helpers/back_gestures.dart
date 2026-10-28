import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An Android predictive back swipe from the left edge, as the platform
/// sends it: start, half way, commit.
Future<void> swipeBack(WidgetTester tester) async {
  const codec = StandardMethodCodec();
  Future<void> send(String method, [Object? arguments]) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
  await send('startBackGesture', {
    'touchOffset': [5.0, 300.0],
    'progress': 0.0,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('updateBackGestureProgress', {
    'touchOffset': [100.0, 300.0],
    'progress': 0.5,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('commitBackGesture');
  await tester.pumpAndSettle();
}

/// What the app tells Android about handling back itself, from now on; the
/// app reports only once it is resumed, which this makes it.
List<bool> recordBackReports(WidgetTester tester) {
  final reports = <bool>[];
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        reports.add(call.arguments as bool);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return reports;
}
