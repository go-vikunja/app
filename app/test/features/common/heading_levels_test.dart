import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  SemanticsData semanticsOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  void expectHeading(WidgetTester tester, Finder finder, int level) {
    final data = semanticsOf(tester, finder);
    expect(data.flagsCollection.isHeader, isTrue, reason: '$finder');
    expect(data.headingLevel, level, reason: '$finder');
  }

  Future<void> pumpWidgets(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final now = DateTime(2026, 10, 10, 12);

  testWidgets(
    "an app bar's title is the screen's level-1 heading, one node that also "
    'names the route on Android',
    (tester) async {
      await pumpSignedInApp(
        tester,
        sync: SyncFakes(now: now),
        now: now,
      );
      await openTab(tester, en.tabUpcoming);

      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(en.tabUpcoming),
      );
      expectHeading(tester, title, 1);
      final android = defaultTargetPlatform == TargetPlatform.android;
      expect(semanticsOf(tester, title).flagsCollection.namesRoute, android);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    "the search page's field in the app bar is no heading, and still names "
    'the route on Android, by a label',
    (tester) async {
      await pumpSignedInApp(
        tester,
        sync: SyncFakes(now: now),
        now: now,
      );
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.search),
      );
      await tester.pumpAndSettle();

      final field = semanticsOf(
        tester,
        find.descendant(
          of: find.byType(SearchPage),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.flagsCollection.isTextField, isTrue);
      expect(field.flagsCollection.isHeader, isFalse);
      expect(field.headingLevel, 0);
      expect(
        field.flagsCollection.namesRoute,
        defaultTargetPlatform == TargetPlatform.android,
      );
      // Android names the route by the label; the hint of the empty field
      // follows it.
      expect(field.label.split('\n').first, en.search);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('section headers are level-2 headings', (tester) async {
    await pumpWidgets(
      tester,
      ListView(
        children: const [
          ListSectionHeader(title: 'Overdue', count: 3),
          FormSectionTitle('Colour'),
          DetailSectionHeader(title: 'Attachments'),
          EmptyState(icon: Icons.inbox, title: 'Nothing here', body: 'Yet.'),
        ],
      ),
    );

    expectHeading(tester, find.text('Overdue'), 2);
    expectHeading(tester, find.text('Colour'), 2);
    expectHeading(tester, find.text('Attachments'), 2);
    expectHeading(tester, find.text('Nothing here'), 2);
  });

  testWidgets("a sheet's title is a level-1 heading", (tester) async {
    await pumpWidgets(tester, const PickerHeader(title: 'Labels'));

    expectHeading(tester, find.text('Labels'), 1);
  });

  testWidgets("the task sheet's title is a level-1 heading, its sections "
      'level 2', (tester) async {
    final data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [sampleTask(id: 1, title: 'Write report')];
    await pumpSignedInApp(tester, sync: data, now: now);
    unawaited(
      showTaskDetail(
        tester.element(find.byType(Scaffold).first),
        task: data.tasks.find(1)!,
      ),
    );
    await tester.pumpAndSettle();

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(TaskDetailSheet), matching: finder);
    expectHeading(tester, inSheet(find.text('Write report')), 1);
    // Below the property card, which a bare task has too.
    await tester.ensureVisible(
      find
          .descendant(
            of: find.byType(TaskDetailSheet),
            matching: find.byType(DetailSectionHeader, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    );
    await tester.pumpAndSettle();
    final sections = inSheet(find.byType(DetailSectionHeader));
    expect(sections, findsWidgets);
    expectHeading(
      tester,
      find.descendant(of: sections.first, matching: find.byType(Text)).first,
      2,
    );
  });
}
