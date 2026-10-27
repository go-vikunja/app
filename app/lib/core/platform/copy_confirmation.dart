import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/android_version.dart';

part 'copy_confirmation.g.dart';

/// Whether the system shows a copy to the clipboard itself, as Android
/// does from version 13 on; a message of the app's own would say it twice.
@Riverpod(keepAlive: true)
Future<bool> systemConfirmsCopies(Ref ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  final major = await ref.watch(androidMajorVersionProvider.future);
  return major != null && major >= 13;
}
