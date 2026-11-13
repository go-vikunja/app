import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_taps.dart';

final _log = Logger('WidgetActions');

/// What the Android widget worker (`WidgetActionsWorker.kt`) starts by
/// library and name in an engine of its own, and waits for.
@pragma('vm:entry-point')
Future<void> widgetActionsMain() => runWidgetActions();

/// The worker's own channel on that engine: `finished` ends its wait.
const widgetWorkerChannel = MethodChannel('io.vikunja.app/widget_worker');

/// The queued Done taps applied through the shared Done, every account's
/// widgets published again, then the worker told, which ends it. Never
/// throws.
Future<void> runWidgetActions({
  Future<ProviderContainer> Function() createContainer =
      createWidgetActionContainer,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  configureLogging();
  final ProviderContainer container;
  try {
    container = await createContainer();
  } on Object catch (error) {
    _log.severe('Could not start for the widget actions: ${error.runtimeType}');
    await _tellWorker();
    return;
  }
  try {
    await importWidgetTaps(container);
    await container.read(widgetRefresherProvider).refreshAll();
  } on Object catch (error) {
    _log.warning('The widget actions failed: ${error.runtimeType}');
  } finally {
    container.dispose();
    await _tellWorker();
  }
}

Future<void> _tellWorker() async {
  try {
    await widgetWorkerChannel.invokeMethod<void>('finished');
  } on Object catch (error) {
    _log.warning('Could not tell the widget worker: ${error.runtimeType}');
  }
}

/// Like the notification action's: session managers that never refresh,
/// so a Done whose token has expired stays queued for a background drain
/// (D39).
Future<ProviderContainer> createWidgetActionContainer() async =>
    ProviderContainer(
      overrides: [
        clientIdentityProvider.overrideWithValue(await ClientIdentity.load()),
        deviceAppLocalizationsProvider.overrideWithValue(
          await loadDeviceAppLocalizations(SharedPreferencesStore()),
        ),
        ...widgetActionOverrides,
      ],
    );

final List<Override> widgetActionOverrides = [
  ...backgroundActionOverrides,
  appPartProvider.overrideWithValue(AppPart.widgetAction),
];
