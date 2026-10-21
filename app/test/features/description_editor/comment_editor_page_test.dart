import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/route_report.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

const _me = User(id: 7, username: 'alice', name: 'Alice Example');
const _anna = User(id: 9, username: 'anna', name: 'Anna');

void main() {
  final now = DateTime(2026, 10, 12, 12);
  late SyncFakes data;
  late FakeEditorBridges bridges;
  late FakeUserRepository users;
  final mine = sampleComment(id: 2, author: _me, html: '<p>Mine</p>');

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 3, title: 'Acme')];
    data.tasks.all = [sampleTask(id: 4, title: 'Ship', projectId: 3)];
    data.details
      ..me = _me
      ..commentsByTask[4] = [mine];
    bridges = FakeEditorBridges();
    users = FakeUserRepository(
      projectUsers: {
        3: [_anna],
      },
    );
  });

  Future<List<Object?>> openEditor(
    WidgetTester tester, {
    TaskComment? comment,
    bool withTarget = true,
  }) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        bridges.override,
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    final target = comment ?? mine;
    final popped = <Object?>[];
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push<Object>(
            AppRoutes.commentEdit(4, target.id),
            extra: withTarget
                ? CommentTarget(taskId: 4, projectId: 3, comment: target)
                : null,
          )
          .then(popped.add),
    );
    await tester.pumpAndSettle();
    return popped;
  }

  Finder saveButton() => find.widgetWithText(TextButton, en.taskEditSave);

  testWidgets("opens with the comment, the comment's texts and the people of "
      "the task's project", (tester) async {
    await openEditor(tester);

    final init = bridges.last.init!;
    expect(init.html, '<p>Mine</p>');
    expect(init.placeholder, en.commentComposerHint);
    expect(init.label, en.commentEditorTitle);
    expect(find.text(en.commentEditorTitle), findsOneWidget);

    bridges.last.emit(const MentionQuery('an'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(users.searches, [(3, 'an')]);
  });

  testWidgets('Save sends the edit online and comes back with the stored '
      'comment', (tester) async {
    final popped = await openEditor(tester);
    bridges.last.edit('<p>Mine, edited</p>');
    await tester.pump();

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(data.details.calls, ['editComment 4 2']);
    expect(data.details.sentHtml, ['<p>Mine, edited</p>']);
    expect(find.byType(DescriptionEditorPage), findsNothing);
    final saved = popped.single! as TaskComment;
    expect(saved.id, 2);
    expect(saved.html, '<p>Mine, edited</p>');
    expect(saved.author, _me);
  });

  testWidgets('an unchanged comment leaves without writing', (tester) async {
    final popped = await openEditor(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(data.details.calls, isEmpty);
    expect(popped, [isNull]);
  });

  testWidgets('an emptied comment is refused and the editor stays', (
    tester,
  ) async {
    await openEditor(tester);
    bridges.last.edit('<p>  </p>');
    await tester.pump();

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text(en.commentEmptyRefused), findsOneWidget);
    expect(data.details.calls, isEmpty);
    expect(find.byType(DescriptionEditorPage), findsOneWidget);
  });

  testWidgets('a refused save says why and keeps the edit', (tester) async {
    final others = sampleComment(id: 5);
    data.details.commentsByTask[4] = [others];
    await openEditor(tester, comment: others);
    bridges.last.edit('<p>Not mine</p>');
    await tester.pump();

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text(en.commentFailedNotAuthor), findsOneWidget);
    expect(find.byType(DescriptionEditorPage), findsOneWidget);
    expect(bridges.last.readOnly.last, isFalse);
  });

  testWidgets('the edit survives the platform reporting the route list back, '
      'which drops the comment the push carried', (tester) async {
    await openEditor(tester);
    bridges.last.edit('<p>Mine, edited</p>');
    await tester.pump();

    await reportRouteFromPlatform(tester);

    expect(find.byType(DescriptionEditorPage), findsOneWidget);
    expect(bridges.created, hasLength(1));
    expect(find.text(en.commentEditorTitle), findsOneWidget);
  });

  testWidgets('without the comment the route goes to the Overview', (
    tester,
  ) async {
    await openEditor(tester, withTarget: false);

    expect(find.byType(DescriptionEditorPage), findsNothing);
    expect(bridges.created, isEmpty);
  });
}
