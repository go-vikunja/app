import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';

extension SubscriberReminders on RegisteredAccount {
  /// The user's id when this account's reminders and due dates follow its
  /// subscriptions, as its server sends reminders only to a task's
  /// subscribers (D80); null otherwise, which keeps D17's creator or
  /// assignee. A link-share guest can follow nothing and keeps D17.
  int? get subscriberId =>
      !account.isLinkShare &&
          connection.capabilities.has(Capability.remindersToSubscribers)
      ? account.userId
      : null;
}
