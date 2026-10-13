import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';

part 'inbox_providers.g.dart';

/// The active account's notifications, newest first; stays loading while
/// no account is signed in.
@riverpod
Stream<List<ActivityItem>> inboxItems(Ref ref) {
  final repository = ref.watch(activityRepositoryProvider);
  if (repository == null) return const Stream.empty();
  final userId = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.activeAccount?.account.userId,
    ),
  );
  return repository.watchAll().map(
    (notifications) => [
      for (final notification in notifications)
        ActivityItem.fromNotification(notification, userId: userId),
    ],
  );
}

@riverpod
Stream<int> unreadActivityCount(Ref ref) =>
    ref.watch(activityRepositoryProvider)?.watchUnreadCount() ??
    const Stream.empty();
