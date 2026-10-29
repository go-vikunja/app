import 'dart:io';
import 'dart:ui' show AppLifecycleState, Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/files/link_share_actions.dart';
import 'package:vikunja_mobile/core/files/platform_file_actions.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/plugin_attachment_picker.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/auth_fakes.dart';

// Every round trip the app starts itself runs as an excursion, so leaving
// the app for it does not lock the app; plain links do not (their opener
// has no excursion at all).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppExcursions excursions;

  setUp(() {
    excursions = AppExcursions(now: () => DateTime.utc(2026, 10, 27, 9));
    addTearDown(excursions.dispose);
  });

  /// [answer] for every call on [name]; what each call saw in `active`.
  List<String> mockChannel(String name, Object? Function(MethodCall) answer) {
    final seen = <String>[];
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen.add('${call.method} ${excursions.active}');
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return seen;
  }

  test('the browser sign-in', () async {
    final seen = mockChannel(
      'flutter_web_auth_2',
      (_) => '$oauthCallbackScheme://oauth/callback?code=c',
    );

    final callback = await FlutterWebAuthenticator(excursions: excursions)
        .authenticate(
          Uri.parse('https://tasks.example.org/oauth/authorize'),
          callbackUrlScheme: oauthCallbackScheme,
        );

    expect(callback?.queryParameters['code'], 'c');
    expect(seen, ['authenticate true']);
    expect(excursions.active, isFalse);
  });

  test("Android's document picker: the pick, not the copy", () async {
    final seen = mockChannel(
      ChannelDocumentPicker.channelName,
      (call) => switch (call.method) {
        'pick' => [
          {'uri': 'content://docs/1', 'name': 'a.pdf', 'size': 1, 'mime': null},
        ],
        _ => {'path': '/cache/picked/a.pdf'},
      },
    );

    final picked = await ChannelDocumentPicker(excursions: excursions)
        .pick(maxBytes: 10, imagesOnly: false, multiple: true);

    expect(picked.files.single.name, 'a.pdf');
    expect(seen, ['pick true', 'copy false']);
  });

  test('the camera', () async {
    final seen = mockChannel(
      'plugins.flutter.io/image_picker',
      (_) => '/data/cache/shot.jpg',
    );

    await PluginAttachmentPicker(excursions: excursions).takePhoto();

    expect(seen.single, endsWith(' true'));
    expect(excursions.active, isFalse);
  });

  group('files', () {
    final file = File('/cache/attachments/report.pdf');

    testWidgets('"open with" lasts until the app is back from the other '
        'app; "save as" and sharing are round trips', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final seen = mockChannel(PlatformFileActions.channelName, (_) => true);
      final shared = <bool>[];
      final actions = PlatformFileActions(
        android: true,
        share: (_) async {
          shared.add(excursions.active);
          return const ShareResult('x', ShareResultStatus.success);
        },
        excursions: excursions,
      );

      expect(await actions.openWith(file, mimeType: 'application/pdf'), isTrue);
      expect(excursions.active, isTrue);
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
      expect(excursions.active, isFalse);

      await actions.saveAs(
        file,
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
      );
      await actions.share(
        file,
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
      );

      expect(seen, ['openWith true', 'saveAs true']);
      expect(shared, [true]);
      expect(excursions.active, isFalse);
    });

    test('a link through the share sheet', () async {
      final shared = <bool>[];
      final actions = PlatformLinkShareActions(
        share: (_) async {
          shared.add(excursions.active);
          return const ShareResult('x', ShareResultStatus.dismissed);
        },
        excursions: excursions,
      );

      await actions.shareLink(Uri.parse('https://tasks.example.org/share/x'));

      expect(shared, [true]);
      expect(excursions.active, isFalse);
    });
  });

  testWidgets('the app language page lasts until the app is back, on '
      'Android and iOS; one that did not open ends at once', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var opened = true;
    final seen = mockChannel(deviceChannel.name, (_) => opened);

    for (final (android, ios) in [(true, false), (false, true)]) {
      final settings = PlatformAppLanguageSettings(
        excursions: excursions,
        android: android,
        ios: ios,
      );
      expect(await settings.open(), isTrue);
      expect(excursions.active, isTrue);
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
      expect(excursions.active, isFalse);
    }

    opened = false;
    await PlatformAppLanguageSettings(
      excursions: excursions,
      android: true,
    ).open();
    await tester.pump();

    expect(seen, [
      'openAppLocaleSettings true',
      'openAppSettings true',
      'openAppLocaleSettings true',
    ]);
    expect(excursions.active, isFalse);
  });

  group('notifications', () {
    late List<String> seen;
    late Object? Function(MethodCall call) answer;

    setUp(() {
      answer = (_) => true;
      seen = mockChannel(
        'dexterous.com/flutter/local_notifications',
        (call) => answer(call),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    LocalNotificationGateway gateway() => LocalNotificationGateway(
      texts: localNotificationTexts(lookupAppLocalizations(const Locale('en'))),
      preferences: MemoryPreferencesStore(),
      excursions: excursions,
    );

    test('the permission request and the exact alarm page are round '
        'trips', () async {
      await gateway().requestPermission();
      await gateway().openExactAlarmSettings();

      expect(seen, contains('requestNotificationsPermission true'));
      expect(seen, contains('requestExactAlarmsPermission true'));
      expect(excursions.active, isFalse);
    });

    testWidgets('the notification settings page lasts until the app is '
        'back; one that did not open ends at once', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await gateway().openNotificationSettings();
      expect(seen, ['openAppNotificationSettings true']);
      expect(excursions.active, isTrue);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(excursions.active, isFalse);

      answer = (_) => false;
      await gateway().openNotificationSettings();
      await tester.pump();
      expect(excursions.active, isFalse);
      // Checked before the tear-downs run.
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
