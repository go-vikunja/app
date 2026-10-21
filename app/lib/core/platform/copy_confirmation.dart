import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';

part 'copy_confirmation.g.dart';

final _log = Logger('CopyConfirmation');

/// Whether the system shows a copy to the clipboard itself, as Android
/// does from version 13 on; a message of the app's own would say it twice.
/// The version is the one the app remembered when it started.
@Riverpod(keepAlive: true)
Future<bool> systemConfirmsCopies(Ref ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final release = await ref
        .watch(preferencesStoreProvider)
        .getString(androidVersionKey);
    final major = int.tryParse(_leadingNumber.stringMatch(release ?? '') ?? '');
    return major != null && major >= 13;
  } on Object catch (error) {
    _log.fine('Android version unavailable: ${error.runtimeType}');
    return false;
  }
}

final _leadingNumber = RegExp(r'^\d+');
