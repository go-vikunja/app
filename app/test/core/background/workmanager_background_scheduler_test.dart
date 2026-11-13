import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/background/workmanager_background_scheduler.dart';
import 'package:workmanager/workmanager.dart';

final class _Registration {
  new(this.kind, this.uniqueName, this.taskName, this.arguments);

  final String kind;
  final String uniqueName;
  final String taskName;
  final Map<String, Object?> arguments;
}

final class _FakeWorkmanager implements WorkmanagerClient {
  final List<_Registration> registrations = [];
  int cancelAllCalls = 0;

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
  }) async => registrations.add(
    _Registration('periodic', uniqueName, taskName, {
      'frequency': frequency,
      'initialDelay': initialDelay,
      'network': constraints?.networkType,
      'policy': existingWorkPolicy,
    }),
  );

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    bool expedited = false,
  }) async => registrations.add(
    _Registration('oneOff', uniqueName, taskName, {
      'network': constraints?.networkType,
      'policy': existingWorkPolicy,
      'outOfQuota': outOfQuotaPolicy,
      'expedited': expedited,
    }),
  );

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

void main() {
  late _FakeWorkmanager workmanager;

  setUp(() => workmanager = _FakeWorkmanager());

  WorkmanagerBackgroundScheduler scheduler(TargetPlatform platform) =>
      WorkmanagerBackgroundScheduler(client: workmanager, platform: platform);

  test('Android: every 30 min with a network, updating the job', () async {
    await scheduler(TargetPlatform.android).registerPeriodicSync();

    final registration = workmanager.registrations.single;
    expect(registration.kind, 'periodic');
    expect(registration.uniqueName, 'io.vikunja.app.sync');
    expect(registration.taskName, 'io.vikunja.app.sync');
    expect(registration.arguments, {
      'frequency': const Duration(minutes: 30),
      'initialDelay': null,
      'network': NetworkType.connected,
      'policy': ExistingPeriodicWorkPolicy.update,
    });
  });

  test(
    'iOS: the BGTaskScheduler identifier, 30 min as the earliest begin',
    () async {
      await scheduler(TargetPlatform.iOS).registerPeriodicSync();

      final registration = workmanager.registrations.single;
      expect(registration.uniqueName, BackgroundTasks.sync);
      expect(registration.taskName, BackgroundTasks.sync);
      expect(
        registration.arguments['initialDelay'],
        const Duration(minutes: 30),
      );
      expect(registration.arguments['network'], isNull);
    },
  );

  test('Android: a drain is plain one-off work with a network, never '
      'expedited (which fails below Android 12), chained after a running '
      'one', () async {
    await scheduler(TargetPlatform.android).enqueueDrain();

    final registration = workmanager.registrations.single;
    expect(registration.kind, 'oneOff');
    expect(registration.uniqueName, 'io.vikunja.app.drain');
    expect(registration.taskName, BackgroundTasks.drain);
    expect(registration.arguments, {
      'network': NetworkType.connected,
      'policy': ExistingWorkPolicy.append,
      'outOfQuota': null,
      'expedited': false,
    });
  });

  test('iOS: a drain is a no-op', () async {
    await scheduler(TargetPlatform.iOS).enqueueDrain();

    expect(workmanager.registrations, isEmpty);
  });

  test('cancelAll cancels everything', () async {
    await scheduler(TargetPlatform.android).cancelAll();

    expect(workmanager.cancelAllCalls, 1);
  });

  test('the iOS identifier is the one Info.plist and AppDelegate name', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(
      RegExp(
        r'<key>BGTaskSchedulerPermittedIdentifiers</key>\s*<array>\s*'
        '<string>([^<]+)</string>',
      ).firstMatch(plist)?.group(1),
      BackgroundTasks.sync,
    );
    expect(
      RegExp(r'<key>UIBackgroundModes</key>\s*<array>\s*<string>fetch</string>')
          .hasMatch(plist),
      isTrue,
    );
    expect(appDelegate, contains('"${BackgroundTasks.sync}"'));
    expect(appDelegate, contains('WorkmanagerPlugin.registerLaunchHandlers()'));
  });
}
