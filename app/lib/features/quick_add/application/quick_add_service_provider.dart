import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/known_users_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';

part 'quick_add_service_provider.g.dart';

/// The active account's quick add; null while nobody is signed in. Rebuilt
/// whenever the projects, labels, known people or settings it plans with
/// change, so a watcher plans again.
@riverpod
QuickAddService? quickAddService(Ref ref) {
  final tasks = ref.watch(taskRepositoryProvider);
  final labels = ref.watch(labelRepositoryProvider);
  final users = ref.watch(userRepositoryProvider);
  if (tasks == null || labels == null || users == null) return null;
  // Right after an account switch the lists still hold the previous
  // account's rows; its ids must not reach the new account's repositories.
  T? current<T>(ProviderListenable<AsyncValue<T>> provider) =>
      ref.watch(provider).unwrapPrevious().value;
  return LocalQuickAddService(
    snapshot: QuickAddSnapshot(
      projects: current(projectsProvider) ?? const [],
      labels: current(allLabelsProvider) ?? const [],
      knownUsers: current(knownUsersProvider) ?? const [],
      settings: current(userSettingsProvider) ?? const UserSettings(),
    ),
    tasks: tasks,
    labels: labels,
    users: users,
    now: ref.watch(clockProvider),
  );
}
