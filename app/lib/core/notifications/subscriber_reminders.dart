import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';

extension SubscriberReminders on RegisteredAccount {
  /// The user's id when this account's reminders and due dates follow its
  /// subscriptions, as its server sends reminders only to a task's
  /// subscribers; null otherwise, which keeps the tasks the user created or
  /// is assigned to. A link-share guest can follow nothing and keeps those
  /// (decision log: Notifications and widgets).
  int? get subscriberId =>
      !account.isLinkShare &&
          connection.capabilities.has(Capability.remindersToSubscribers)
      ? account.userId
      : null;
}
