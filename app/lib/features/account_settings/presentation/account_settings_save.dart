import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('AccountSettingsSave');

sealed class AccountSettingsSave {
  const new();
}

final class AccountSettingsSaved extends AccountSettingsSave {
  const new();
}

/// The server refused the value; [message] belongs at the control.
final class AccountSettingsRefused extends AccountSettingsSave {
  const new(this.message);

  final String message;
}

final class AccountSettingsNotSaved extends AccountSettingsSave {
  const new(this.error);

  final Object error;
}

/// Sends [changes] of [field] to the server. Screen readers hear "Saved";
/// a failure gives a heavy haptic and, while [context] is mounted, either
/// the refusal to show at the control, also announced (except for the
/// name, whose field announces its own error), or a snackbar.
Future<AccountSettingsSave> saveAccountSettings(
  BuildContext context,
  AccountSettingsRepository repository,
  AccountSettingsField field,
  UserSettingsChanges changes,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final announcer = Announcer.of(context);
  try {
    await repository.update(changes);
    announcer.say(l10n.accountSettingsSaved);
    return const AccountSettingsSaved();
  } on Object catch (error) {
    _log.warning('Saving an account setting failed: ${error.runtimeType}');
    unawaited(HapticFeedback.heavyImpact());
    if (!context.mounted) return AccountSettingsNotSaved(error);
    final fieldError = accountSettingsFieldError(l10n, error, field, changes);
    if (fieldError != null) {
      announcer.say(
        fieldError,
        onlyIfPlatformAnnounces: field == AccountSettingsField.name,
      );
      return AccountSettingsRefused(fieldError);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(accountSettingsFailureText(l10n, error))),
      );
    return AccountSettingsNotSaved(error);
  }
}
