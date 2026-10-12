import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_de.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

import '../../helpers/sample_data.dart';

void main() {
  final work = sampleProject(id: 7, title: 'Work');
  final task = sampleTask(id: 12, title: 'Water the plants', projectId: 7);

  test('the title is the task title; the body names the kind and the '
      'project', () {
    final describe = describeNotificationsWith(AppLocalizationsEn());

    expect(describe(task, ScheduledNotificationKind.reminder, work), (
      title: 'Water the plants',
      body: 'Reminder · Work',
    ));
    expect(describe(task, ScheduledNotificationKind.dueDate, work), (
      title: 'Water the plants',
      body: 'Due now · Work',
    ));
  });

  test('a prefixed identifier is added, the index-only one is not', () {
    final describe = describeNotificationsWith(AppLocalizationsEn());

    expect(
      describe(
        task.copyWith(identifier: 'WORK-12'),
        ScheduledNotificationKind.reminder,
        work,
      ).body,
      'Reminder · Work · WORK-12',
    );
    expect(
      describe(
        task.copyWith(identifier: '-12'),
        ScheduledNotificationKind.reminder,
        work,
      ).body,
      'Reminder · Work',
    );
  });

  test('without a local project the body stays short', () {
    final describe = describeNotificationsWith(AppLocalizationsEn());

    expect(
      describe(task, ScheduledNotificationKind.reminder, null).body,
      'Reminder',
    );
    expect(
      describe(task, ScheduledNotificationKind.dueDate, null).body,
      'Due now',
    );
  });

  test('German', () {
    final describe = describeNotificationsWith(AppLocalizationsDe());

    expect(
      describe(task, ScheduledNotificationKind.reminder, work).body,
      'Erinnerung · Work',
    );
    expect(
      describe(task, ScheduledNotificationKind.dueDate, null).body,
      'Jetzt fällig',
    );
  });
}
