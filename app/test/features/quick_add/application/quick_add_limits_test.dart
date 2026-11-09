import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

import '../../../helpers/label_user_fakes.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/sync_fakes.dart';
import '../../../helpers/zero_random.dart';
import 'fake_grammar.dart';

// Vikunja 2.8.0 refuses a title over 1000 code points and more than 100
// reminders; a queued create over either would fail for good.
void main() {
  final now = DateTime(2026, 10, 12, 10, 15);
  late FakeTaskRepository tasks;

  setUp(() => tasks = FakeTaskRepository(FakeSyncEngine(clock: () => now)));

  LocalQuickAddService service({
    UserSettings settings = const UserSettings(),
  }) => LocalQuickAddService(
    snapshot: QuickAddSnapshot(
      projects: [sampleProject(id: 4, title: 'Inbox')],
      settings: settings.copyWith(defaultProjectId: 4),
    ),
    tasks: tasks,
    labels: FakeLabelRepository(),
    users: FakeUserRepository(),
    now: () => now,
    grammar: fakeGrammar,
    random: ZeroRandom(),
  );

  test('a line over the limit is cut; its rest starts the description, '
      "before the sheet's", () async {
    final long = ('word ' * 250).trim();

    await service().submit(
      '$long\nshort',
      extras: const QuickAddExtras(description: '<p>Notes</p>'),
    );

    expect(tasks.creates.map((task) => (task.title, task.description)), [
      (('word ' * 200).trim(), '<p>${('word ' * 50).trim()}</p><p>Notes</p>'),
      ('short', '<p>Notes</p>'),
    ]);
  });

  test('a single line over the limit loses nothing', () async {
    final emoji = '😀' * (Task.maxTitleLength + 2);

    await service().submit(emoji);

    final created = tasks.creates.single;
    expect(created.title, '😀' * Task.maxTitleLength);
    expect(created.description, '<p>😀😀</p>');
  });

  test("the sheet's reminders and the default ones stop at the limit, the "
      "sheet's first", () async {
    final sheet = [
      for (var minutes = 1; minutes <= Task.maxReminders; minutes++)
        TaskReminder(reminder: DateTime.utc(2026, 11, 1, 0, minutes)),
    ];

    await service(
      settings: const UserSettings(
        quickAddDefaultReminders: [Duration(hours: -1)],
      ),
    ).submit('Pay rent tomorrow', extras: QuickAddExtras(reminders: sheet));

    expect(tasks.creates.single.reminders, sheet);
  });
}
