import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/activity/activity_notification_texts.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/inbox/presentation/activity_texts.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';

import '../features/inbox/inbox_samples.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';

/// The web's `getProjectTitle` and view titles.
void main() {
  group('projectDisplayTitle', () {
    test('translates the Favorites list by its id', () {
      expect(
        projectDisplayTitle(en, 'Favorites', projectId: Project.favoritesId),
        'Favorites',
      );
      expect(
        projectDisplayTitle(de, 'Favorites', projectId: Project.favoritesId),
        'Favoriten',
      );
    });

    test('translates the default names by their exact title', () {
      expect(projectDisplayTitle(de, 'Inbox'), 'Eingang');
      expect(projectDisplayTitle(en, 'Inbox'), 'Inbox');
      expect(
        projectDisplayTitle(de, 'My Open Tasks'),
        'Meine offenen Aufgaben',
      );
      expect(projectDisplayTitle(de, 'inbox'), 'inbox');
      expect(projectDisplayTitle(de, 'Inbox '), 'Inbox ');
      expect(projectDisplayTitle(de, 'My open tasks'), 'My open tasks');
    });

    test('keeps any other title, and a saved filter is found by title', () {
      expect(projectDisplayTitle(de, 'Work', projectId: 3), 'Work');
      expect(
        projectDisplayTitle(de, 'My Open Tasks', projectId: -81),
        'Meine offenen Aufgaben',
      );
    });

    test('a project names itself so', () {
      expect(sampleProject(id: 2, title: 'Inbox').displayTitle(de), 'Eingang');
      expect(sampleProject(id: 3, title: 'Work').displayTitle(de), 'Work');
    });
  });

  test('the view switcher translates the default view titles only', () {
    ProjectView view(String title) => ProjectView(
      id: 1,
      projectId: 1,
      title: title,
      kind: ProjectViewKind.list,
    );
    expect(
      [
        for (final title in ['List', 'Gantt', 'Table', 'Kanban'])
          viewTitle(de, view(title)),
      ],
      ['Liste', 'Gantt', 'Tabelle', 'Kanban'],
    );
    expect(
      [
        for (final title in ['List', 'Gantt', 'Table', 'Kanban'])
          viewTitle(en, view(title)),
      ],
      ['List', 'Gantt', 'Table', 'Kanban'],
    );
    expect(viewTitle(de, view('Board')), 'Board');
    expect(viewTitle(de, view('list')), 'list');
  });

  group('notifications name the project as the screens do', () {
    final task = sampleTask(id: 1, title: 'Water the plants');

    test('local reminders and due dates', () {
      final describe = describeNotificationsWith(de);
      final inbox = sampleProject(id: 2, title: 'Inbox');
      expect(
        describe(task, ScheduledNotificationKind.reminder, inbox).body,
        de.notificationReminderBody('Eingang'),
      );
      expect(
        describe(task, ScheduledNotificationKind.dueDate, inbox).body,
        de.notificationDueBody('Eingang'),
      );
    });

    ActivityItem activity(String name, Map<String, Object?> payload) =>
        ActivityItem.fromNotification(
          inboxNotification(
            id: 1,
            name: name,
            created: DateTime(2026, 10, 12),
            payload: payload,
          ),
        );

    final doer = payloadUser(id: 2, username: 'anna', name: 'Anna');
    final inbox = {'id': 2, 'title': 'Inbox'};

    test('activity notifications', () {
      final created = describeActivity(
        activity('task.created', {
          'doer': doer,
          'task': payloadTask(id: 1, title: 'Water the plants'),
          'project': inbox,
        }),
        l10n: de,
      );
      expect(
        created?.body,
        de.activityNotificationTaskCreated('Anna', 'Eingang'),
      );

      final project = describeActivity(
        activity('project.created', {'doer': doer, 'project': inbox}),
        l10n: de,
      );
      expect(project?.title, 'Eingang');
      expect(
        project?.body,
        de.activityNotificationProjectCreated('Anna', 'Eingang'),
      );
    });

    test('the inbox', () {
      expect(
        describeInboxRow(
          de,
          activity('project.created', {'doer': doer, 'project': inbox}),
        ),
        de.inboxProjectCreated('Anna', 'Eingang'),
      );
    });
  });
}
