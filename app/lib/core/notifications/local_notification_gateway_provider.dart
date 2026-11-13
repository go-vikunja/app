import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart'
    show AppLifecycleListener, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'local_notification_gateway_provider.g.dart';

final _log = Logger('DeviceLanguage');

@Riverpod(keepAlive: true)
NotificationGateway notificationGateway(Ref ref) {
  final gateway = LocalNotificationGateway(
    texts: localNotificationTexts(ref.read(deviceAppLocalizationsProvider)),
    preferences: ref.watch(preferencesStoreProvider),
    onResponse: ref.watch(notificationResponsesProvider).add,
    onBackgroundResponse: ref.watch(notificationBackgroundEntryPointProvider),
    excursions: ref.watch(appExcursionsProvider),
  );
  // Not rebuilt for a new language: the activity tray keeps this instance.
  ref.listen(
    deviceAppLocalizationsProvider,
    (_, l10n) => unawaited(gateway.updateTexts(localNotificationTexts(l10n))),
  );
  return gateway;
}

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

/// The app's strings for what the OS shows outside the widget tree:
/// notifications and their channels, widgets and the app lock prompt.
/// Bootstrap overrides the build with what [loadDeviceAppLocalizations]
/// resolved, and [deviceLanguageFollowerProvider] keeps it in the device's
/// language; the headless entry points override it with a value. The
/// default serves the tests.
@Riverpod(keepAlive: true)
class DeviceAppLocalizations extends _$DeviceAppLocalizations {
  @override
  AppLocalizations build() =>
      _resolveAppLocalizations(PlatformDispatcher.instance.locales);

  /// Switches to the language [locales] resolve to, as
  /// [loadDeviceAppLocalizations] resolves them, and notes it for the
  /// headless isolates; nothing when that is the current one or when no
  /// locale is reported.
  Future<void> follow(Iterable<Locale> locales) async {
    if (locales.isEmpty) return;
    final l10n = _resolveAppLocalizations(locales);
    if (l10n.localeName == state.localeName) return;
    state = l10n;
    await _noteLocale(ref.read(preferencesStoreProvider), l10n);
  }
}

/// In the app: [deviceAppLocalizationsProvider] follows a change of the
/// device or per-app language while the app runs, which Android reports
/// without restarting the activity, and looks again once it is listened to
/// and on every resume. iOS restarts the app instead. Bootstrap listens.
@Riverpod(keepAlive: true)
void deviceLanguageFollower(Ref ref) {
  void follow([List<Locale>? locales]) => unawaited(
    ref
        .read(deviceAppLocalizationsProvider.notifier)
        .follow(locales ?? WidgetsBinding.instance.platformDispatcher.locales)
        .catchError(
          (Object error) => _log.warning(
            'Could not note the device language: ${error.runtimeType}',
          ),
        ),
  );
  final observer = _LocalesObserver(follow);
  WidgetsBinding.instance.addObserver(observer);
  final lifecycle = AppLifecycleListener(onResume: follow);
  ref.onDispose(() {
    lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(observer);
  });
  // A language set before this listens, as the update over the previous
  // app does during bootstrap, would otherwise wait for the next resume.
  // A microtask, because a build must not change another provider.
  scheduleMicrotask(() {
    if (ref.mounted) follow();
  });
}

final class _LocalesObserver with WidgetsBindingObserver {
  new(this._onChange);

  final void Function(List<Locale>? locales) _onChange;

  @override
  void didChangeLocales(List<Locale>? locales) => _onChange(locales);
}

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
    final l10n = _resolveAppLocalizations(reported);
    await _noteLocale(preferences, l10n);
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

/// The first of [locales] the app supports, else English.
AppLocalizations _resolveAppLocalizations(Iterable<Locale> locales) {
  for (final locale in locales) {
    if (AppLocalizations.delegate.isSupported(locale)) {
      return lookupAppLocalizations(locale);
    }
  }
  return lookupAppLocalizations(const Locale('en'));
}

Future<void> _noteLocale(PreferencesStore preferences, AppLocalizations l10n) =>
    preferences.setString(
      notificationLocaleKey,
      l10n.localeName.replaceAll('_', '-'),
    );
