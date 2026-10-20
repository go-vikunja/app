import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_search.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'task_search_providers.g.dart';

@riverpod
TaskSearch accountTaskSearch(Ref ref, String accountId) => LocalTaskSearch(
  ref.watch(appDatabaseProvider(accountId)),
  now: ref.watch(clockProvider),
);

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
TaskSearch? taskSearch(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountTaskSearchProvider(accountId));
}
