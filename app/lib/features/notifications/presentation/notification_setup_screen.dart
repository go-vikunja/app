import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';

final _log = Logger('NotificationSetup');

/// Asks for the notification permission once per device, after the first
/// account's first sync; on Android 14+ a second step asks for exact
/// alarms. Marking the setup done is what moves the router on to the
/// shell, so "Not now" and "Skip" are the same step without the request.
class NotificationSetupScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotificationSetupScreen> createState() =>
      _NotificationSetupScreenState();
}

enum _Step { permission, exactAlarms }

class _NotificationSetupScreenState
    extends ConsumerState<NotificationSetupScreen> {
  _Step _step = _Step.permission;
  var _busy = false;
  var _finished = false;

  /// A request the plugin refuses (one still in progress, a channel error)
  /// ends the setup as well: the Account tab's status line says what the OS
  /// allows and offers the request again.
  Future<void> _turnOn() async {
    setState(() => _busy = true);
    try {
      final capabilities = await ref
          .read(osNotificationCapabilitiesProvider.notifier)
          .requestPermission();
      if (!mounted) return;
      if (_needsExactAlarms(capabilities)) {
        setState(() => _step = _Step.exactAlarms);
      } else {
        await _finish();
      }
    } on Object catch (error) {
      _log.warning(
        'The notification permission request failed: ${error.runtimeType}',
      );
      await _finish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Only Android distinguishes exact alarms; the gateway answers true
  /// elsewhere.
  bool _needsExactAlarms(NotificationCapabilities capabilities) =>
      capabilities.permission == NotificationPermission.granted &&
      !capabilities.exactAlarms &&
      Theme.of(context).platform == TargetPlatform.android;

  Future<void> _allowExactAlarms() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationGatewayProvider).openExactAlarmSettings();
    } on Object catch (error) {
      _log.warning(
        'The exact alarm settings did not open: ${error.runtimeType}',
      );
      await _finish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The router redirects to the shell once the flag is stored; a flag that
  /// could not be stored leaves the buttons for another try.
  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    try {
      await ref.read(notificationsOnboardingProvider.notifier).markDone();
    } on Object catch (error) {
      _finished = false;
      _log.warning(
        'Could not store the notification setup flag: ${error.runtimeType}',
      );
    }
  }

  /// Back from the system settings with exact alarms allowed.
  void _onCapabilitiesChanged(
    AsyncValue<NotificationCapabilities>? previous,
    AsyncValue<NotificationCapabilities> next,
  ) {
    if (_step == _Step.exactAlarms && (next.value?.exactAlarms ?? false)) {
      unawaited(_finish());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(osNotificationCapabilitiesProvider, _onCapabilitiesChanged);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (title, body) = switch (_step) {
      _Step.permission => (
        l10n.notificationSetupTitle,
        l10n.notificationSetupBody,
      ),
      _Step.exactAlarms => (
        l10n.notificationSetupExactTitle,
        l10n.notificationSetupExactBody,
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    ConnectHeader.logoAsset,
                    width: 72,
                    height: 72,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_step == _Step.permission) ...[
                    const SizedBox(height: 24),
                    _Point(
                      icon: Icons.alarm_outlined,
                      text: l10n.notificationSetupReminders,
                    ),
                    _Point(
                      icon: Icons.event_outlined,
                      text: l10n.notificationSetupDueDates,
                    ),
                    _Point(
                      icon: Icons.person_outline,
                      text: l10n.notificationSetupOnlyYours,
                    ),
                  ],
                  const SizedBox(height: 32),
                  switch (_step) {
                    _Step.permission => FilledButton.icon(
                      onPressed: _busy ? null : () => unawaited(_turnOn()),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: Text(l10n.notificationSetupTurnOn),
                    ),
                    _Step.exactAlarms => FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_allowExactAlarms()),
                      icon: const Icon(Icons.alarm_on_outlined),
                      label: Text(l10n.notificationSetupExactAllow),
                    ),
                  },
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_finish()),
                    child: Text(switch (_step) {
                      _Step.permission => l10n.notificationSetupNotNow,
                      _Step.exactAlarms => l10n.notificationSetupSkip,
                    }, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
