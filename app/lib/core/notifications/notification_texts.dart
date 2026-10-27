import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

/// Title: the task's title. Body: `Reminder · Work` or `Due now · Work`,
/// with the task's identifier when its project has a prefix; without the
/// project part when the project is not known locally. With
/// [NotificationContent.noTitles] only the kind, and nothing of the task.
NotificationDescriber describeNotificationsWith(
  AppLocalizations l10n, {
  NotificationContent content = NotificationContent.all,
}) => (task, kind, project) {
  if (content == NotificationContent.noTitles) {
    return (
      title: switch (kind) {
        ScheduledNotificationKind.reminder =>
          l10n.notificationContentReminderTitle,
        ScheduledNotificationKind.dueDate => l10n.notificationContentDueTitle,
      },
      body: l10n.notificationContentBody,
    );
  }
  final body = switch ((kind, project?.displayTitle(l10n))) {
    (ScheduledNotificationKind.reminder, final title?) =>
      l10n.notificationReminderBody(title),
    (ScheduledNotificationKind.reminder, null) =>
      l10n.notificationReminderBodyNoProject,
    (ScheduledNotificationKind.dueDate, final title?) =>
      l10n.notificationDueBody(title),
    (ScheduledNotificationKind.dueDate, null) =>
      l10n.notificationDueBodyNoProject,
  };
  return (
    title: task.title,
    body: _hasPrefixedIdentifier(task)
        ? l10n.notificationBodyWithIdentifier(body, task.identifier)
        : body,
  );
};

/// `displayIdentifier` falls back to `#<index>`, which says nothing the
/// title does not.
bool _hasPrefixedIdentifier(Task task) =>
    task.identifier.isNotEmpty && task.identifier != '-${task.index}';
