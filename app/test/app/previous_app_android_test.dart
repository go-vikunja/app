import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// What keeps the update over the previous official app (same id on Play)
// from breaking what that app left on the device.
const _main = 'android/app/src/main';

String _read(String path) =>
    File(path)
        .readAsStringSync()
        .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

String? _attribute(String element, String name) =>
    RegExp('\\bandroid:$name="([^"]*)"').firstMatch(element)?[1];

List<String> _elements(String xml, String tag) => [
  for (final match in RegExp(
    '<$tag(?=[\\s/>])[^>]*?(?:/>|>.*?</$tag>)',
    dotAll: true,
  ).allMatches(xml))
    match[0]!,
];

String _startTag(String element) =>
    RegExp('^<[^>]*>', dotAll: true).firstMatch(element)![0]!;

void main() {
  final manifest = _read('$_main/AndroidManifest.xml');

  test("the previous app's reminders find their status bar icon by name, "
      'kept from resource shrinking', () {
    final drawables = _read('$_main/res/values/legacy_drawables.xml');
    final keep = File('$_main/res/raw/keep.xml').readAsStringSync();

    expect(
      drawables,
      matches(
        RegExp(
          r'<item\s+name="vikunja_notification_logo"\s+type="drawable">'
          r'\s*@drawable/ic_notification\s*</item>',
        ),
      ),
    );
    expect(
      RegExp('tools:keep="([^"]*)"').firstMatch(keep)?[1]?.split(','),
      contains('@drawable/vikunja_notification_logo'),
    );
  });

  test('the widgets placed with the previous app keep a provider under its '
      'class name', () {
    final receivers = [
      for (final receiver in _elements(manifest, 'receiver'))
        if (_attribute(_startTag(receiver), 'name') ==
            '.widget.AppWidgetReciever')
          receiver,
    ];

    expect(receivers, hasLength(1));
    final receiver = receivers.single;
    expect(_attribute(_startTag(receiver), 'exported'), 'true');
    expect(
      receiver,
      contains(
        '<action android:name="android.appwidget.action.APPWIDGET_UPDATE" />',
      ),
    );
    final metaData = _elements(receiver, 'meta-data').single;
    expect(_attribute(metaData, 'name'), 'android.appwidget.provider');
    expect(_attribute(metaData, 'resource'), '@xml/widget_tasks_legacy_info');
  });

  test("a widget of the previous app leads to this app's setup and is never "
      'offered in the picker', () {
    final info = _read('$_main/res/xml/widget_tasks_legacy_info.xml');

    expect(
      _attribute(info, 'configure'),
      'io.vikunja.app.widgets.WidgetConfigureActivity',
    );
    expect(
      _attribute(info, 'widgetFeatures')?.split('|'),
      containsAll([
        'hide_from_picker',
        'reconfigurable',
        'configuration_optional',
      ]),
    );
    expect(_attribute(info, 'updatePeriodMillis'), '0');
  });

  test('launcher icons placed with the previous app keep their component, '
      'io.vikunja.app/.MainActivity', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final launchers = [
      for (final tag in ['activity', 'activity-alias'])
        for (final activity in _elements(manifest, tag))
          if (activity.contains('android.intent.action.MAIN') &&
              activity.contains('android.intent.category.LAUNCHER'))
            _attribute(_startTag(activity), 'name'),
    ];

    expect(
      RegExp(
        r'^\s*namespace = "([^"]*)"',
        multiLine: true,
      ).firstMatch(gradle)?[1],
      'io.vikunja.app',
    );
    expect(launchers, ['.MainActivity']);
    expect(
      File('$_main/kotlin/io/vikunja/app/MainActivity.kt').readAsStringSync(),
      allOf(
        matches(RegExp(r'^package io\.vikunja\.app$', multiLine: true)),
        matches(RegExp(r'^class MainActivity\b', multiLine: true)),
      ),
    );
  });

  test("the device channel answers the update path's calls", () {
    final channel = File('$_main/kotlin/io/vikunja/app/DeviceChannel.kt')
        .readAsStringSync();

    for (final method in [
      'previousAppTraces',
      'clearPreviousApp',
      'setAppLanguage',
    ]) {
      expect(channel, contains('"$method" ->'), reason: method);
    }
    expect(channel, contains('call.argument<String>("language")'));
  });

  // Glance and AppWidgetManager need a device; the JVM tests cover what
  // these calls decide.
  test('a widget of the previous app asks to be set up, is redrawn by its '
      'own provider, is told apart for the app, and the provider goes once '
      'no widget uses it', () {
    String kotlin(String path) =>
        File('$_main/kotlin/io/vikunja/app/$path').readAsStringSync();

    expect(
      kotlin('widgets/TasksWidget.kt'),
      contains(
        'followsActiveAccount = !LegacyWidgets.isLegacy(context, appWidgetId)',
      ),
    );
    final configure = kotlin('widgets/WidgetConfigureActivity.kt');
    expect(
      configure,
      matches(
        RegExp(
          r'val provider = AppWidgetManager\.getInstance\(this\)'
          r'\.getAppWidgetInfo\(appWidgetId\)\?\.provider$',
          multiLine: true,
        ),
      ),
    );
    expect(configure, contains('.setComponent(provider)'));
    expect(
      RegExp(
        r'override fun onDisabled\(context: Context\) \{[^}]*'
        r'LegacyWidgets\.disableIfUnused\(context\)',
      ).hasMatch(kotlin('widget/AppWidgetReciever.kt')),
      isTrue,
    );
    expect(
      RegExp(
        r'fun clear\(context: Context\) \{.*'
        r'LegacyWidgets\.disableIfUnused\(context\)',
        dotAll: true,
      ).hasMatch(kotlin('PreviousApp.kt')),
      isTrue,
    );
    expect(
      File(
        '../plugins/vikunja_widgets/android/src/main/kotlin/io/vikunja/'
        'vikunja_widgets/WidgetInstances.kt',
      ).readAsStringSync(),
      contains(
        '"followsActiveAccount" to kind.followsActiveAccount(receiver),',
      ),
      reason: "the app's Widgets page tells them apart",
    );
  });
}
