import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';

String lockAfterLabel(AppLocalizations l10n, LockAfter lockAfter) =>
    switch (lockAfter) {
      LockAfter.immediately => l10n.privacyLockAfterImmediately,
      LockAfter.oneMinute => l10n.privacyLockAfterMinutes(1),
      LockAfter.fiveMinutes => l10n.privacyLockAfterMinutes(5),
      LockAfter.fifteenMinutes => l10n.privacyLockAfterMinutes(15),
      LockAfter.oneHour => l10n.privacyLockAfterHours(1),
    };

/// "App lock: Off" or "App lock: On · after 1 minute", for the Account
/// tab's entry.
String appLockSummary(AppLocalizations l10n, PrivacySettings settings) =>
    switch (settings) {
      PrivacySettings(appLock: false) => l10n.privacyEntryAppLockOff,
      PrivacySettings(lockAfter: LockAfter.immediately) =>
        l10n.privacyEntryAppLockImmediately,
      PrivacySettings(:final lockAfter) => l10n.privacyEntryAppLockAfter(
        lockAfterLabel(l10n, lockAfter),
      ),
    };
