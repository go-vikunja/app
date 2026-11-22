import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_header_layout.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

/// The task sheet's header as screen readers find it: each ancestor in
/// the breadcrumb a link node of its own tap target, and the breadcrumb
/// read before the actions, also where it wraps below them.
void main() {
  final home = sampleProject(id: 1, title: 'Home');
  final kitchen = sampleProject(id: 2, title: 'Kitchen', parent: 1);
  const actions = ['Edit', 'Follow', 'Favorite', 'More', 'Close details'];

  Future<void> pumpHeader(WidgetTester tester, {required double width}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              // As around the sheet's header: a node above that a link
              // without one of its own would merge into.
              child: Semantics(
                container: true,
                child: SizedBox(
                  width: width,
                  child: DetailHeaderLayout(
                    breadcrumb: ProjectBreadcrumb(
                      path: [home, kitchen],
                      onOpen: (_) {},
                    ),
                    actions: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in actions)
                          IconButton(
                            onPressed: () {},
                            tooltip: action,
                            icon: const Icon(Icons.circle_outlined),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> readOrder(WidgetTester tester) => [
    for (final node in tester.semantics.simulatedAccessibilityTraversal())
      if (node.getSemanticsData() case final data)
        if (data.label.isNotEmpty) data.label else data.tooltip,
  ];

  for (final (name, width, wraps) in [
    ('on a phone, the breadcrumb below the actions', 411.0, true),
    ('on a wide pane, all on one line', 900.0, false),
  ]) {
    testWidgets(name, (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHeader(tester, width: width);
      final link = tester.getRect(find.text('Home'));
      final edit = tester.getRect(find.byTooltip('Edit'));
      expect(link.top >= edit.bottom, wraps);

      final node = tester.getSemantics(find.text('Home'));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isLink, isTrue);
      expect(data.label, 'Home');
      expect(data.hint, en.taskDetailOpenProjectHint);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // The InkWell's 48 dp, not the header's area with its buttons.
      expect(node.rect.height, 48);
      expect(node.rect.width, lessThan(120));
      expect(node.childrenCount, 0);

      expect(
        readOrder(tester),
        containsAllInOrder(['Home', 'Kitchen', ...actions]),
      );
      semantics.dispose();
    });
  }
}
