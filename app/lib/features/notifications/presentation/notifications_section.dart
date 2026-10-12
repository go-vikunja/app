import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/account_notification_preferences.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';

final _log = Logger('NotificationsSection');

/// The OS id of the test notification; the scheduler's ids are hashes
/// far above it.
const testNotificationOsId = 1;

/// The task id a test notification carries; a tap on it opens the Account
/// tab instead of a task.
const testNotificationTaskId = 0;

/// The account's reminder and due-date switches, what the OS allows, how
/// many notifications are scheduled, and a test notification.
class NotificationsSection extends ConsumerWidget {
  const new({required this.entry, super.key});

  final RegisteredAccount entry;

  Future<void> _write(
    WidgetRef ref,
    NotificationPreferences preferences,
  ) async {
    try {
      await ref
          .read(notificationPreferencesStoreProvider)
          .write(entry.id, preferences);
    } on Object catch (error) {
      _log.warning(
        'Could not store the notification preferences: ${error.runtimeType}',
      );
    }
  }

  Future<void> _sendTest(WidgetRef ref, AppLocalizations l10n) async {
    try {
      await ref
          .read(notificationGatewayProvider)
          .showNow(
            osId: testNotificationOsId,
            title: l10n.notificationTestTitle,
            body: l10n.notificationTestBody,
            payload: NotificationPayload(
              accountId: entry.id,
              taskId: testNotificationTaskId,
              key: 'test',
            ).toJson(),
          );
    } on Object catch (error) {
      _log.warning(
        'Could not show the test notification: ${error.runtimeType}',
      );
    }
  }

  Future<void> _quietly(Future<void> Function() action, String what) async {
    try {
      await action();
    } on Object catch (error) {
      _log.warning('Could not $what: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final preferences =
        ref.watch(accountNotificationPreferencesProvider(entry.id)).value ??
        const NotificationPreferences();
    final capabilities = ref.watch(osNotificationCapabilitiesProvider).value;
    final granted = capabilities?.permission == NotificationPermission.granted;
    final scheduled = ref
        .watch(scheduledNotificationCountProvider(entry.id))
        .unwrapPrevious()
        .value;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.notificationsHeading,
            style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationsReminders),
          subtitle: Text(l10n.notificationsRemindersSubtitle),
          value: preferences.reminders,
          onChanged: (value) =>
              unawaited(_write(ref, preferences.copyWith(reminders: value))),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationsDueDates),
          subtitle: Text(l10n.notificationsDueDatesSubtitle),
          value: preferences.dueDates,
          onChanged: (value) =>
              unawaited(_write(ref, preferences.copyWith(dueDates: value))),
        ),
        if (capabilities case final capabilities? when !granted)
          _StatusLine(
            icon: Icons.notifications_off_outlined,
            text: l10n.notificationsOff,
            action: switch (capabilities.permission) {
              NotificationPermission.notAsked => TextButton(
                onPressed: () => unawaited(
                  _quietly(
                    ref
                        .read(osNotificationCapabilitiesProvider.notifier)
                        .requestPermission,
                    'ask for the notification permission',
                  ),
                ),
                child: Text(l10n.notificationsTurnOn),
              ),
              _ => TextButton(
                onPressed: () => unawaited(
                  _quietly(
                    ref
                        .read(notificationGatewayProvider)
                        .openNotificationSettings,
                    'open the notification settings',
                  ),
                ),
                child: Text(l10n.notificationsOpenSettings),
              ),
            },
          )
        else if (capabilities case NotificationCapabilities(exactAlarms: false))
          _StatusLine(
            icon: Icons.alarm_off_outlined,
            text: l10n.notificationsMayBeLate,
            action: TextButton(
              onPressed: () => unawaited(
                _quietly(
                  ref.read(notificationGatewayProvider).openExactAlarmSettings,
                  'open the exact alarm settings',
                ),
              ),
              child: Text(l10n.notificationsAllowExactAlarms),
            ),
          ),
        if (scheduled != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.notificationsScheduled(scheduled),
              style: secondary,
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: granted ? () => unawaited(_sendTest(ref, l10n)) : null,
            icon: const Icon(Icons.notification_add_outlined),
            label: Text(l10n.notificationsSendTest),
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const new({required this.icon, required this.text, required this.action});

  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ExcludeSemantics(child: Icon(icon, color: colors.error)),
          ),
          const SizedBox(width: 12),
          // The button goes below the text when large text leaves no room.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(text, style: theme.textTheme.bodyLarge),
                ),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
