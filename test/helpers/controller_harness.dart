/// Harness for controller tests: a [ProviderContainer] wired to the shared
/// fake repositories.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';

import 'test_app.dart';

/// A container backed by [TestRepositories], with [user] seeded as the signed-in
/// user unless it is explicitly null.
({ProviderContainer container, TestRepositories repos}) controllerHarness({
  User? user,
  NotificationHandler? notifications,
  List<Override> extraOverrides = const [],
}) {
  final repos = TestRepositories();
  final container = ProviderContainer(
    overrides: [
      ...repos.overrides,
      if (user != null) currentUserOverride(user),
      if (notifications != null)
        notificationProvider.overrideWith(
          () => _SeededNotification(notifications),
        ),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  return (container: container, repos: repos);
}

class _SeededNotification extends Notification {
  _SeededNotification(this._handler);

  final NotificationHandler _handler;

  @override
  NotificationHandler? build() => _handler;
}

/// Holds an auto-dispose provider alive for the whole test.
///
/// Without a listener Riverpod tears the notifier down as soon as a `read`
/// completes, so the next `.notifier` call would hand back a fresh instance and
/// state transitions would vanish between steps.
void keepAlive<T>(ProviderContainer container, ProviderListenable<T> provider) {
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
}
