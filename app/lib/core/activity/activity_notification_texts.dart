import 'package:characters/characters.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

/// How much of a comment the notification body quotes, in characters as
/// the user sees them.
const activityCommentLength = 80;

/// The OS notification for [item], worded like the web's notification
/// list but with the names spelled out: the title names the task (or the
/// project or team), the body who did what. Null for a kind that is not
/// shown. A name the payload lacks falls back like the inbox's row does.
/// With [NotificationContent.noTitles] the same generic texts for every
/// kind that is shown: no title, name or comment.
({String title, String body})? describeActivity(
  ActivityItem item, {
  required AppLocalizations l10n,
  NotificationContent content = NotificationContent.all,
}) {
  final described = _describe(item, l10n);
  if (described == null || content != NotificationContent.noTitles) {
    return described;
  }
  return (
    title: l10n.notificationContentActivityTitle,
    body: l10n.notificationContentBody,
  );
}

({String title, String body})? _describe(
  ActivityItem item,
  AppLocalizations l10n,
) {
  final doer = item.doerName ?? l10n.inboxSomeone;
  final team = item.teamName ?? l10n.inboxUnnamed;
  final project = switch (item.projectTitle) {
    final title? => projectDisplayTitle(l10n, title),
    null => null,
  };
  String titled(String? title) => title ?? l10n.activityNotificationUntitled;
  return switch (item.kind) {
    ActivityKind.comment => (
      title: titled(item.taskTitle),
      body: switch (_excerpt(item.comment)) {
        final text? => l10n.activityNotificationCommented(doer, text),
        null => l10n.activityNotificationCommentedNoText(doer),
      },
    ),
    ActivityKind.assigned => (
      title: titled(item.taskTitle),
      body: switch (item.targetName) {
        _ when item.targetIsMe => l10n.activityNotificationAssignedYou(doer),
        final assignee? => l10n.activityNotificationAssignedOther(
          doer,
          assignee,
        ),
        null => l10n.activityNotificationAssignedSomeone(doer),
      },
    ),
    ActivityKind.mentioned => (
      title: titled(item.taskTitle),
      body: l10n.activityNotificationMentioned(doer),
    ),
    ActivityKind.taskCreated => (
      title: titled(item.taskTitle),
      body: switch (project) {
        final title? => l10n.activityNotificationTaskCreated(doer, title),
        null => l10n.activityNotificationTaskCreatedNoProject(doer),
      },
    ),
    ActivityKind.taskDeleted => (
      title: titled(item.taskTitle),
      body: l10n.activityNotificationTaskDeleted(doer),
    ),
    ActivityKind.projectCreated => (
      title: titled(project),
      body: l10n.activityNotificationProjectCreated(
        doer,
        project ?? l10n.inboxUnnamed,
      ),
    ),
    ActivityKind.teamMemberAdded => (
      title: titled(item.teamName),
      body: switch (item.targetName) {
        _ when item.targetIsMe => l10n.activityNotificationTeamAddedYou(
          doer,
          team,
        ),
        final member? => l10n.activityNotificationTeamAddedOther(
          doer,
          member,
          team,
        ),
        null => l10n.activityNotificationTeamAddedSomeone(doer, team),
      },
    ),
    ActivityKind.reminder || ActivityKind.other => null,
  };
}

/// Cut between grapheme clusters, so an emoji or an accented letter stays
/// whole.
String? _excerpt(String? text) {
  if (text == null) return null;
  final characters = text.characters;
  if (characters.length <= activityCommentLength) return text;
  final cut = characters.take(activityCommentLength - 1).toString();
  return '${cut.trimRight()}…';
}
