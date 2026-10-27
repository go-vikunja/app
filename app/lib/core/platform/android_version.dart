import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';

part 'android_version.g.dart';

final _log = Logger('AndroidVersion');

/// The major Android version the app remembered when it started; null when
/// it is unknown or the app does not run on Android.
@Riverpod(keepAlive: true)
Future<int?> androidMajorVersion(Ref ref) async {
  try {
    final release = await ref
        .watch(preferencesStoreProvider)
        .getString(androidVersionKey);
    return int.tryParse(_leadingNumber.stringMatch(release ?? '') ?? '');
  } on Object catch (error) {
    _log.fine('Android version unavailable: ${error.runtimeType}');
    return null;
  }
}

final _leadingNumber = RegExp(r'^\d+');
