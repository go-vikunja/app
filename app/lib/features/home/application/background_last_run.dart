import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';

part 'background_last_run.g.dart';

/// When the background sync last ran for [accountId]; null before its
/// first run. Another isolate writes it, so it is read again every minute
/// while the app is in front and when it comes back.
@riverpod
Future<DateTime?> backgroundLastRun(Ref ref, String accountId) {
  ref.watch(clockTickProvider);
  return ref.watch(backgroundRunLogProvider).lastRunAt(accountId);
}
