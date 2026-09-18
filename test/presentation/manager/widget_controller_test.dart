/// The home-screen widget bridge: its pure transforms, and the redraw request it
/// sends the platform. The entry points that need a live client are listed as
/// not covered in test/README.md.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/plugin_mocks.dart';

/// The instant before midnight, where a test that read the real clock twice
/// could see two different days. Pinning it makes "today" unambiguous.
final lastSecondOfTheDay = DateTime(2026, 3, 10, 23, 59, 59);

void main() {
  setUp(() => mockPlatformPlugins());

  group('convertTask', () {
    test('carries the id and title across', () {
      final widgetTask = convertTask(buildTask(id: 12, title: 'Ship it'));

      expect(widgetTask.id, '12');
      expect(widgetTask.title, 'Ship it');
    });

    test('flags a task due today', () {
      final widgetTask = withClock(
        Clock.fixed(lastSecondOfTheDay),
        () => convertTask(buildTask(dueDate: DateTime(2026, 3, 10, 12))),
      );

      expect(widgetTask.today, isTrue);
      expect(widgetTask.dueDate, isNotNull);
    });

    test('does not flag a task due tomorrow', () {
      final widgetTask = withClock(
        Clock.fixed(lastSecondOfTheDay),
        () => convertTask(buildTask(dueDate: DateTime(2026, 3, 11, 12))),
      );

      expect(widgetTask.today, isFalse);
      expect(widgetTask.dueDate, isNotNull);
    });

    test('treats the year-1 sentinel as no due date', () {
      final widgetTask = convertTask(buildTask(dueDate: DateTime.utc(1)));

      expect(widgetTask.dueDate, isNull);
      expect(widgetTask.today, isFalse);
    });

    test('treats a missing due date as no due date', () {
      final widgetTask = convertTask(buildTask(dueDate: null));

      expect(widgetTask.dueDate, isNull);
      expect(widgetTask.today, isFalse);
    });
  });

  group('reRenderWidget', () {
    test('asks the platform to redraw the app widget', () async {
      await reRenderWidget();

      expect(mockWidgetRedraws.single, {
        'name': 'AppWidget',
        'android': null,
        'ios': null,
        'qualifiedAndroidName': 'io.vikunja.app.widget.AppWidgetReciever',
      });
    });
  });

  group('widget payload encoding', () {
    test('a converted task round-trips through json', () {
      final json = jsonEncode([
        convertTask(buildTask(id: 3, title: 'A')).toJSON(),
      ]);

      final decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded.single['id'], '3');
      expect(decoded.single['title'], 'A');
    });
  });
}
