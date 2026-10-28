import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/privacy/application/app_switcher_protection.dart';
import 'package:vikunja_mobile/features/privacy/presentation/lock_after_texts.dart';

final _log = Logger('PrivacyPage');

/// The device's app lock and how long Rurana may be out of sight before it
/// locks, screenshots (Android), what notifications show and whether
/// widgets list task titles. Turning the lock on or off takes the device's
/// screen lock or biometrics first.
class PrivacyPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  var _changingLock = false;
  String? _lockError;
  var _saveFailed = false;

  Future<void> _setAppLock({required bool enabled}) async {
    final l10n = context.l10n;
    setState(() {
      _changingLock = true;
      _lockError = null;
      _saveFailed = false;
    });
    DeviceAuthResult? result;
    try {
      result = await ref
          .read(appLockControllerProvider.notifier)
          .setAppLock(
            enabled: enabled,
            prompt: DeviceAuthPrompt.forReason(
              l10n,
              enabled
                  ? l10n.privacyAppLockReasonOn
                  : l10n.privacyAppLockReasonOff,
            ),
          );
    } on Object catch (error) {
      _log.warning('Could not store the app lock: ${error.runtimeType}');
    }
    if (!mounted) return;
    final error = switch (result) {
      null => l10n.privacySaveFailed,
      DeviceAuthResult.success || DeviceAuthResult.cancelled => null,
      // The controller turned it off: there is no screen lock to ask for.
      DeviceAuthResult.noCredentials when !enabled => null,
      DeviceAuthResult.noCredentials => l10n.privacyAppLockUnsupported,
      DeviceAuthResult.lockedOut => l10n.privacyAppLockLockedOut,
      DeviceAuthResult.inProgress => l10n.appLockPromptStuck,
      DeviceAuthResult.unavailable => l10n.privacyAppLockFailed,
    };
    if (result == DeviceAuthResult.noCredentials) {
      ref.invalidate(deviceAuthSupportedProvider);
    }
    setState(() {
      _changingLock = false;
      _lockError = error;
    });
    if (error != null) announce(context, error);
  }

  Future<void> _chooseLockAfter(LockAfter current) async {
    final l10n = context.l10n;
    final picked = await showOptionSheet<LockAfter>(
      context,
      title: l10n.privacyLockAfter,
      options: [
        for (final option in LockAfter.values)
          SheetOption(
            value: option,
            label: lockAfterLabel(l10n, option),
            selected: option == current,
          ),
      ],
    );
    if (picked == null || picked == current || !mounted) return;
    await _change((settings) => settings.copyWith(lockAfter: picked));
  }

  Future<void> _change(
    PrivacySettings Function(PrivacySettings settings) edit,
  ) async {
    setState(() => _saveFailed = false);
    try {
      await ref.read(privacySettingsControllerProvider.notifier).change(edit);
    } on Object catch (error) {
      _log.warning(
        'Could not store the privacy settings: ${error.runtimeType}',
      );
      if (!mounted) return;
      setState(() => _saveFailed = true);
      announce(context, context.l10n.privacySaveFailed);
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await ref.read(notificationGatewayProvider).openNotificationSettings();
    } on Object catch (error) {
      _log.warning(
        'Could not open the notification settings: ${error.runtimeType}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final platform = Theme.of(context).platform;
    final stored = ref.watch(privacySettingsControllerProvider).value;
    final settings = stored?.settings ?? const PrivacySettings();
    final supported = ref.watch(deviceAuthSupportedProvider).value;
    final bestEffort = ref.watch(appSwitcherBestEffortProvider).value ?? false;
    final lockError = _lockError;
    // A lock that is on can always be turned off: without a screen lock the
    // controller turns it off without a prompt.
    final canChangeLock =
        stored != null &&
        !_changingLock &&
        (settings.appLock || (supported ?? false));
    final lockSubtitle = supported == false && !settings.appLock
        ? l10n.privacyAppLockUnsupported
        : l10n.privacyAppLockSubtitle;

    return Scaffold(
      appBar: AppBar(title: ScreenTitle(l10n.privacyTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (stored?.unreadable ?? false)
              _PageNote(
                icon: Icons.error_outline,
                text: l10n.privacySettingsUnreadable,
              ),
            if (_saveFailed)
              _PageNote(
                icon: Icons.error_outline,
                text: l10n.privacySaveFailed,
              ),
            SectionCard(
              title: l10n.privacyAppLockHeading,
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.lock_outline),
                  title: Text(l10n.privacyAppLockSwitch),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lockSubtitle),
                      if (lockError != null) SettingErrorText(lockError),
                    ],
                  ),
                  value: settings.appLock,
                  onChanged: canChangeLock
                      ? (value) => unawaited(_setAppLock(enabled: value))
                      : null,
                ),
                if (settings.appLock)
                  SettingChoiceTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: l10n.privacyLockAfter,
                    value: lockAfterLabel(l10n, settings.lockAfter),
                    help: l10n.privacyLockAfterRestart,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        unawaited(_chooseLockAfter(settings.lockAfter)),
                  ),
                SettingsNote(
                  icon: Icons.visibility_off_outlined,
                  text: bestEffort
                      ? l10n.privacyAppSwitcherBestEffort
                      : l10n.privacyAppSwitcherHidden,
                ),
              ],
            ),
            if (platform == TargetPlatform.android)
              SectionCard(
                title: l10n.privacyScreenshotsHeading,
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.screenshot_outlined),
                    title: Text(l10n.privacyBlockScreenshots),
                    subtitle: Text(l10n.privacyBlockScreenshotsSubtitle),
                    value: settings.blockScreenshots,
                    onChanged: stored == null
                        ? null
                        : (value) => unawaited(
                            _change(
                              (current) =>
                                  current.copyWith(blockScreenshots: value),
                            ),
                          ),
                  ),
                ],
              ),
            RadioGroup<NotificationContent>(
              groupValue: settings.notificationContent,
              onChanged: (value) {
                if (value == null) return;
                unawaited(
                  _change(
                    (current) => current.copyWith(notificationContent: value),
                  ),
                );
              },
              child: SectionCard(
                title: l10n.privacyNotificationContentHeading,
                children: [
                  _ContentChoice(
                    value: NotificationContent.all,
                    title: l10n.privacyNotificationContentAll,
                    subtitle: l10n.privacyNotificationContentAllSubtitle,
                    enabled: stored != null,
                  ),
                  _ContentChoice(
                    value: NotificationContent.hiddenOnLockScreen,
                    title: l10n.privacyNotificationContentHidden,
                    // Android leaves them off the secure lock screen
                    // entirely; iOS shows a placeholder when set up so.
                    subtitle: platform == TargetPlatform.android
                        ? l10n.privacyNotificationContentHiddenSubtitleAndroid
                        : l10n.privacyNotificationContentHiddenSubtitle,
                    enabled: stored != null,
                  ),
                  // iOS leaves the lock screen previews to its own
                  // setting.
                  if (platform == TargetPlatform.iOS &&
                      settings.notificationContent ==
                          NotificationContent.hiddenOnLockScreen)
                    SettingsNote(
                      icon: Icons.info_outline,
                      text: l10n.privacyNotificationContentIosHint,
                      action: TextButton(
                        onPressed: () => unawaited(_openNotificationSettings()),
                        child: Text(l10n.notificationsOpenSettings),
                      ),
                    ),
                  _ContentChoice(
                    value: NotificationContent.noTitles,
                    title: l10n.privacyNotificationContentNoTitles,
                    subtitle: l10n.privacyNotificationContentNoTitlesSubtitle,
                    enabled: stored != null,
                  ),
                ],
              ),
            ),
            SectionCard(
              title: l10n.privacyWidgetsHeading,
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.widgets_outlined),
                  title: Text(l10n.privacyWidgetTitles),
                  subtitle: Text(l10n.privacyWidgetTitlesSubtitle),
                  value: settings.widgetTitles,
                  onChanged: stored == null
                      ? null
                      : (value) => unawaited(
                          _change(
                            (current) => current.copyWith(widgetTitles: value),
                          ),
                        ),
                ),
              ],
            ),
            if (settings.widgetTitles)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ListNote(
                  icon: Icons.visibility_outlined,
                  text: l10n.widgetsPrivacyNote,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContentChoice extends StatelessWidget {
  const new({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final NotificationContent value;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      RadioListTile<NotificationContent>.adaptive(
        value: value,
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: enabled,
      );
}

class _PageNote extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: ListNote(icon: icon, text: text),
  );
}
