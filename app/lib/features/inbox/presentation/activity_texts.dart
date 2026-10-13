import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';

/// The web's notification texts with the doer's name in front, e.g.
/// "Anna commented on #12"; a name the payload lacks falls back like the
/// OS notification's text does.
String describeInboxRow(AppLocalizations l10n, ActivityItem item) {
  final doer = item.doerName ?? l10n.inboxSomeone;
  final task = item.taskIdentifier ?? item.taskTitle ?? l10n.inboxATask;
  final team = item.teamName ?? l10n.inboxUnnamed;
  return switch (item.kind) {
    ActivityKind.comment => l10n.inboxCommented(doer, task),
    ActivityKind.assigned => switch (item.targetName) {
      _ when item.targetIsMe => l10n.inboxAssignedYou(doer, task),
      final assignee? => l10n.inboxAssigned(doer, assignee, task),
      null => l10n.inboxAssignedSomeone(doer, task),
    },
    ActivityKind.mentioned => l10n.inboxMentioned(doer, task),
    ActivityKind.taskCreated => l10n.inboxTaskCreated(doer, task),
    ActivityKind.taskDeleted => l10n.inboxTaskDeleted(doer, task),
    ActivityKind.projectCreated => l10n.inboxProjectCreated(
      doer,
      item.projectTitle ?? l10n.inboxUnnamed,
    ),
    ActivityKind.teamMemberAdded => switch (item.targetName) {
      _ when item.targetIsMe => l10n.inboxAddedYouToTeam(doer, team),
      final member? => l10n.inboxAddedToTeam(doer, member, team),
      null => l10n.inboxAddedSomeoneToTeam(doer, team),
    },
    ActivityKind.reminder => l10n.inboxReminder(task),
    ActivityKind.other => l10n.inboxOther,
  };
}

IconData activityIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.comment => Icons.chat_bubble_outline,
  ActivityKind.assigned => Icons.assignment_ind_outlined,
  ActivityKind.mentioned => Icons.alternate_email,
  ActivityKind.taskCreated => Icons.add_task,
  ActivityKind.taskDeleted => Icons.delete_outline,
  ActivityKind.projectCreated => Icons.create_new_folder_outlined,
  ActivityKind.teamMemberAdded => Icons.group_add_outlined,
  ActivityKind.reminder => Icons.alarm,
  ActivityKind.other => Icons.notifications_none,
};
