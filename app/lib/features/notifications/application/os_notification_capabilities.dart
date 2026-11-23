import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

part 'os_notification_capabilities.g.dart';

final _log = Logger('Notifications');

/// What the OS allows right now; read again whenever the app comes back to
/// the front, because the user changes it in the system settings.
@Riverpod(keepAlive: true)
class OsNotificationCapabilities extends _$OsNotificationCapabilities {
  @override
  Future<NotificationCapabilities> build() async {
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(lifecycle.dispose);
    final gateway = ref.watch(notificationGatewayProvider);
    // Once per isolate; the scheduler may have done it already.
    await gateway.initialize();
    return await gateway.capabilities();
  }

  /// On a resume nobody awaits; a gateway error keeps the previous answer,
  /// as the schedulers do.
  Future<void> refresh() async {
    try {
      final capabilities = await ref
          .read(notificationGatewayProvider)
          .capabilities();
      final before = state.value;
      state = AsyncData(capabilities);
      // The schedulers reconcile on a resume only after a hide; the shade
      // and a settings page beside the app come back without one. On iOS
      // after the widgets' Done taps, whose reminders a run would schedule
      // again (decision log: Notifications and widgets).
      if (before != null &&
          (before.permission != capabilities.permission ||
              before.exactAlarms != capabilities.exactAlarms)) {
        final schedulers = ref.read(notificationSchedulersProvider);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          unawaited(afterWidgetTapImports(ref, schedulers.reconcileAll));
        } else {
          schedulers.reconcileAll();
        }
      }
    } on Object catch (error) {
      _log.warning(
        'Could not read what the OS allows for notifications: '
        '${error.runtimeType}',
      );
    }
  }

  /// The schedulers see the answer through the registry: the OS dialog
  /// does not always come with a resume, and comes without a hide.
  Future<NotificationCapabilities> requestPermission() async {
    final gateway = ref.read(notificationGatewayProvider);
    await gateway.initialize();
    final capabilities = await gateway.requestPermission();
    state = AsyncData(capabilities);
    ref.read(notificationSchedulersProvider).reconcileAll();
    return capabilities;
  }
}
