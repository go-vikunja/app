import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/android_version.dart';

part 'app_switcher_protection.g.dart';

/// Whether the app switcher hides the app only as far as its own cover
/// is drawn in time: Android 12 and older, where the system cannot
/// leave the Recents thumbnail out. An unknown version counts as older.
@riverpod
Future<bool> appSwitcherBestEffort(Ref ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  final major = await ref.watch(androidMajorVersionProvider.future);
  return major == null || major < 13;
}
