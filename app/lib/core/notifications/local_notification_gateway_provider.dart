import 'dart:async';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'local_notification_gateway_provider.g.dart';

@Riverpod(keepAlive: true)
NotificationGateway notificationGateway(Ref ref) => LocalNotificationGateway(
  texts: localNotificationTexts(ref.watch(deviceAppLocalizationsProvider)),
  preferences: ref.watch(preferencesStoreProvider),
  onResponse: ref.watch(notificationResponsesProvider).add,
  onBackgroundResponse: ref.watch(notificationBackgroundEntryPointProvider),
);

/// The top-level `@pragma('vm:entry-point')` function the plugin runs in its
/// own engine for an action that shows no UI. Overridden in bootstrap with
/// the action handler's entry point; null leaves those actions unwired.
@Riverpod(keepAlive: true)
DidReceiveBackgroundNotificationResponseCallback?
notificationBackgroundEntryPoint(Ref ref) => null;

/// Taps, and actions that show the app, reported while the app runs. The
/// tap listener subscribes here; the tap that launched the app comes from
/// [notificationLaunchResponseProvider].
@Riverpod(keepAlive: true)
NotificationResponses notificationResponses(Ref ref) {
  final responses = NotificationResponses();
  ref.onDispose(responses.dispose);
  return responses;
}

@Riverpod(keepAlive: true)
Future<NotificationResponse?> notificationLaunchResponse(Ref ref) async {
  final gateway = ref.watch(notificationGatewayProvider);
  if (gateway is! LocalNotificationGateway) return null;
  return await gateway.launchResponse();
}

/// A broadcast stream that holds what arrived before anyone listened, so a
/// tap reported during the first frames is not lost.
final class NotificationResponses {
  new() {
    _controller = StreamController<NotificationResponse>.broadcast(
      onListen: _flush,
    );
  }

  late final StreamController<NotificationResponse> _controller;
  final _waiting = <NotificationResponse>[];

  Stream<NotificationResponse> get stream => _controller.stream;

  void add(NotificationResponse response) {
    if (_controller.isClosed) return;
    if (_controller.hasListener) {
      _controller.add(response);
    } else {
      _waiting.add(response);
    }
  }

  void _flush() {
    _waiting
      ..forEach(_controller.add)
      ..clear();
  }

  void dispose() => unawaited(_controller.close());
}

LocalNotificationTexts localNotificationTexts(AppLocalizations l10n) =>
    LocalNotificationTexts(
      channelName: l10n.notificationChannelReminders,
      channelDescription: l10n.notificationChannelRemindersDescription,
      markDone: l10n.notificationActionDone,
      snooze10Minutes: l10n.notificationActionSnooze10Minutes,
      snooze1Hour: l10n.notificationActionSnooze1Hour,
      activityChannelName: l10n.notificationChannelActivity,
      activityChannelDescription: l10n.notificationChannelActivityDescription,
    );

/// Where an isolate that resolved the device locale notes its tag, for one
/// that gets no locales.
const notificationLocaleKey = 'notifications.locale';

/// The app's strings for the notification texts, without a widget tree.
/// Bootstrap and the background entry point override this with what
/// [loadDeviceAppLocalizations] resolved; the default serves the tests.
@Riverpod(keepAlive: true)
AppLocalizations deviceAppLocalizations(Ref ref) =>
    _supportedAppLocalizations(PlatformDispatcher.instance.locales) ??
    lookupAppLocalizations(const Locale('en'));

/// The first of [locales] the app supports, else English when the engine
/// reports any locale, the tag noted under [notificationLocaleKey] when it
/// reports none (the headless engine the plugin starts on iOS has no view
/// to take them from), else English. A resolved locale is noted for that
/// case.
Future<AppLocalizations> loadDeviceAppLocalizations(
  PreferencesStore preferences, {
  Iterable<Locale>? locales,
}) async {
  final reported = locales ?? PlatformDispatcher.instance.locales;
  if (reported.isNotEmpty) {
    final l10n =
        _supportedAppLocalizations(reported) ??
        lookupAppLocalizations(const Locale('en'));
    await preferences.setString(
      notificationLocaleKey,
      l10n.localeName.replaceAll('_', '-'),
    );
    return l10n;
  }
  final noted = await preferences.getString(notificationLocaleKey);
  if (noted != null) {
    final subtags = noted.split('-');
    final locale = Locale(
      subtags.first,
      subtags.length > 1 ? subtags[1] : null,
    );
    if (AppLocalizations.delegate.isSupported(locale)) {
      return lookupAppLocalizations(locale);
    }
  }
  return lookupAppLocalizations(const Locale('en'));
}

AppLocalizations? _supportedAppLocalizations(Iterable<Locale> locales) {
  for (final locale in locales) {
    if (AppLocalizations.delegate.isSupported(locale)) {
      return lookupAppLocalizations(locale);
    }
  }
  return null;
}
