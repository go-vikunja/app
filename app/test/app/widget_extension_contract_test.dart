import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

// The iOS extension decodes the app's JSON by property name and finds the
// app's notifications by their payload, and the Android widgets read the
// same JSON by key; a name that drifts decodes as nil or null or matches
// nothing, without an error. The XCTests (ios/RunnerTests) run only on a
// Mac and the JVM tests parse a hand-written sample, so the contract with
// the Dart side is checked here.
void main() {
  const extensionFolder = 'ios/VikunjaWidgets';
  final widgetData = File('$extensionFolder/WidgetData.swift')
      .readAsStringSync();
  final markDone = File('$extensionFolder/MarkDoneIntent.swift')
      .readAsStringSync();
  final widgetModel = File(
    'android/app/src/main/kotlin/io/vikunja/app/widgets/WidgetModel.kt',
  ).readAsStringSync();

  String block(String source, String header, {required String indent}) {
    final start = source.indexOf(header);
    if (start == -1) throw StateError('No $header');
    return source.substring(start, source.indexOf('\n$indent}\n', start));
  }

  String kotlinFunction(String source, String header) {
    final start = source.indexOf(header);
    if (start == -1) throw StateError('No $header');
    final indent = source.substring(source.lastIndexOf('\n', start) + 1, start);
    return source.substring(
      start,
      source.indexOf(RegExp('\n$indent[)}]\n'), start),
    );
  }

  Set<String> kotlinReads(String function) => {
    for (final match in RegExp(
      r'\bjson\??\.\w+\("(\w+)"\)',
    ).allMatches(function))
      match[1]!,
  };

  Set<String> storedProperties(String block, {required String indent}) => {
    for (final match in RegExp(
      '^${indent}var (\\w+): [^{\\n]+\$',
      multiLine: true,
    ).allMatches(block))
      match[1]!,
  };

  Set<String> keys(Map<String, Object?> json) => json.keys.toSet();

  final row = WidgetRow(
    taskId: 12,
    title: 'Water the plants',
    dueLabel: 'Today, 14:00',
    absoluteDueLabel: 'Oct 26, 14:00',
    dueAt: DateTime.utc(2026, 10, 26, 13),
    tone: WidgetDueTone.today,
    priorityLabel: 'High',
    priorityLevel: 3,
    projectTitle: 'Home',
    projectColor: '1973ff',
    projectColorLight: '1973ff',
    projectColorDark: '4a8cff',
    canDone: true,
    semanticsLabel: 'Water the plants',
    overdueSemanticsLabel: 'Water the plants, overdue',
    absoluteSemanticsLabel: 'Water the plants, Oct 26',
    absoluteOverdueSemanticsLabel: 'Water the plants, overdue Oct 26',
    doneLabel: 'Mark done',
    link: 'vikunja-io.vikunja.app://widget/task/12',
  );
  const text = WidgetText('Title', body: 'Body', action: 'Action');
  final snapshot = WidgetSnapshot(
    key: 'account.today',
    accountId: 'account',
    state: WidgetSnapshotState.ok,
    title: 'Today',
    subtitle: 'Alice',
    generatedAt: DateTime.utc(2026, 10, 26, 9),
    validUntil: DateTime.utc(2026, 10, 26, 23),
    changesAt: [DateTime.utc(2026, 10, 26, 13)],
    rows: [row],
    total: 3,
    moreLabel: '+2 more',
    countLabel: '3 tasks',
    empty: text,
    message: text,
    messageLink: 'vikunja-io.vikunja.app://widget/account',
    link: 'vikunja-io.vikunja.app://widget/list',
    newTaskLink: 'vikunja-io.vikunja.app://widget/new-task',
    newTaskLabel: 'New task',
    staleNotice: 'Open Vikunja to update',
  );

  group('every property the extension decodes is a key the app writes', () {
    String listSnapshot() =>
        block(widgetData, 'struct ListSnapshot: Decodable {', indent: '');

    test('a row', () {
      final swift = storedProperties(
        block(listSnapshot(), 'struct Row: Decodable {', indent: '  '),
        indent: '    ',
      );

      expect(
        swift,
        containsAll([
          'due',
          'dueAbsolute',
          'label',
          'labelOverdue',
          'labelAbsolute',
          'labelAbsoluteOverdue',
        ]),
      );
      expect(keys(row.toJson()), containsAll(swift));
    });

    test('a list', () {
      final swift = storedProperties(listSnapshot(), indent: '  ');

      expect(swift, containsAll(['validUntil', 'staleNotice']));
      expect(keys(snapshot.toJson()), containsAll(swift));
    });

    test('a text', () {
      final swift = storedProperties(
        block(widgetData, 'struct WidgetText: Decodable {', indent: ''),
        indent: '  ',
      );

      expect(swift, isNotEmpty);
      expect(keys(text.toJson()), containsAll(swift));
    });
  });

  group('every key the Android widgets read is a key the app writes', () {
    Set<String> reads(String header) =>
        kotlinReads(kotlinFunction(widgetModel, header));

    test('a row', () {
      final kotlin = reads('private fun rowOf(');

      expect(kotlin, containsAll(['id', 'canDone', 'colorDark']));
      expect(keys(row.toJson()), containsAll(kotlin));
    });

    test('a list', () {
      final kotlin = reads('fun parse(text: String): Snapshot?');

      expect(kotlin, containsAll(['key', 'rows', 'moreLabel']));
      expect(keys(snapshot.toJson()), containsAll(kotlin));
    });

    test('a text', () {
      final kotlin = reads('private fun textOf(');

      expect(kotlin, containsAll(['title', 'action']));
      expect(keys(text.toJson()), containsAll(kotlin));
    });
  });

  test('the Android widgets know every state the app writes and every tone '
      'they color', () {
    Set<String> cases(String header) => {
      for (final match in RegExp(
        r'"(\w+)" ->',
      ).allMatches(kotlinFunction(widgetModel, header)))
        match[1]!,
    };

    expect(cases('private fun stateOf('), {
      for (final state in WidgetSnapshotState.values) state.name,
    });
    // Any other tone reads as none.
    expect(cases('private fun toneOf('), {
      for (final tone in WidgetDueTone.values)
        if (tone != WidgetDueTone.none) tone.name,
    });
  });

  test('an entry speaks the label of the tone and due text it shows, and '
      "the timeline has an entry at every row's due instant", () {
    final timeline = File('$extensionFolder/TasksTimeline.swift')
        .readAsStringSync();
    final spokenLabel = block(widgetData, 'func spokenLabel(', indent: '  ');

    expect(
      timeline,
      contains('row.spokenLabel(stale: stale, overdue: tone == .overdue)'),
    );
    expect(
      spokenLabel,
      stringContainsInOrder([
        'labelOverdue',
        'labelAbsolute',
        'labelAbsoluteOverdue',
      ]),
    );
    expect(
      block(widgetData, 'func entryDates(', indent: '  '),
      contains(r'rows.compactMap(\.dueAt)'),
    );
  });

  test("a widget's Done finds the task's reminders and due date by the "
      'account and key of their payload', () {
    final payload = jsonDecode(
      const NotificationPayload(
        accountId: 'account',
        taskId: 42,
        key: '42:due',
      ).toJson(),
    ) as Map<String, Object?>;
    String swiftKey(String key) => key.replaceFirst('42', r'\(taskId)');
    final reminder = reminderNotificationKey(42, 3);

    expect(payload.keys, containsAll(['account', 'key']));
    expect(markDone, contains('fields["account"] as? String == accountId'));
    expect(markDone, contains('let key = fields["key"] as? String'));
    expect(markDone, contains('key == "${swiftKey(dueNotificationKey(42))}"'));
    expect(
      markDone,
      contains(
        'key.hasPrefix("'
        '${swiftKey(reminder.substring(0, reminder.lastIndexOf(':') + 1))}")',
      ),
    );
  });

  // An internal of flutter_local_notifications: check it on every upgrade.
  test('flutter_local_notifications keeps the payload under "payload" in a '
      "notification's userInfo, where the extension reads it", () {
    final config = File('../.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
    final plugin = packages.cast<Map<String, Object?>>().singleWhere(
      (package) => package['name'] == 'flutter_local_notifications',
    );
    final rootUri = plugin['rootUri']! as String;
    final source = File.fromUri(
      config.uri
          .resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/')
          .resolve(
            'ios/flutter_local_notifications/Sources/'
            'flutter_local_notifications/FlutterLocalNotificationsPlugin.m',
          ),
    ).readAsStringSync();

    expect(source, contains('NSString *const PAYLOAD = @"payload";'));
    expect(source, contains('userDict[PAYLOAD] = payload;'));
    expect(markDone, contains('userInfo["payload"] as? String'));
  });
}
