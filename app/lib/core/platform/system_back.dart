import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/android_version.dart';

part 'system_back.g.dart';

/// Whether Android hands system back to the framework only as a pop, as it
/// does before version 14; from 14 on it comes as a predictive back
/// gesture, which the routes take themselves. An unknown version counts as
/// 14.
@Riverpod(keepAlive: true)
Future<bool> systemBackArrivesAsPop(Ref ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  final major = await ref.watch(androidMajorVersionProvider.future);
  return major != null && major < 14;
}
