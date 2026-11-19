import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/subscriber_reminders.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'task_details_repository_providers.g.dart';

@riverpod
TaskDetailsRepository accountTaskDetailsRepository(Ref ref, String accountId) =>
    LocalTaskDetailsRepository(
      ref.watch(appDatabaseProvider(accountId)),
      ref.watch(readClientProvider(accountId)),
      ref.watch(writeClientProvider(accountId)),
      subscriberId: ref.watch(
        accountsProvider.select(
          (accounts) => accounts.value?.find(accountId)?.subscriberId,
        ),
      ),
      me: ref.watch(
        accountsProvider.select((accounts) {
          final account = accounts.value?.find(accountId)?.account;
          if (account == null) return null;
          return User(
            id: account.userId,
            username: account.username,
            name: account.displayName == account.username
                ? ''
                : account.displayName,
          );
        }),
      ),
      now: ref.watch(clockProvider),
    );

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
TaskDetailsRepository? taskDetailsRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountTaskDetailsRepositoryProvider(accountId));
}
