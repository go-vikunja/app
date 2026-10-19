import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_resolver.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver.dart';

part 'task_resolver_providers.g.dart';

@riverpod
TaskResolver accountTaskResolver(Ref ref, String accountId) =>
    LocalTaskResolver(
      ref.watch(appDatabaseProvider(accountId)),
      ref.watch(readClientProvider(accountId)),
    );

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
TaskResolver? taskResolver(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountTaskResolverProvider(accountId));
}
