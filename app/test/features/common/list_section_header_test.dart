import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';

import '../../helpers/large_screens.dart';

double _trailingCap(WidgetTester tester, String trailing) => tester
    .widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.text(trailing),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    )
    .constraints
    .maxWidth;

Widget _card() => const SectionCard(
  title: 'Notifications',
  trailing: Text('Only on this device'),
  children: [ListTile(title: Text('Reminders'))],
);

void main() {
  testWidgets("a section header's trailing text takes at most 40 % of the "
      "header's own width: the phone's width on a phone", (tester) async {
    useWindow(tester, androidPhone);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListView(children: [_card()])),
      ),
    );

    expect(_trailingCap(tester, 'Only on this device'), 144);
  });

  testWidgets("and the band's width in a capped list on a tablet", (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadableWidth.builder(
            maxWidth: ReadableWidth.list,
            builder: (context, width, inset) => ListView(
              padding: EdgeInsets.symmetric(horizontal: inset),
              children: [_card()],
            ),
          ),
        ),
      ),
    );

    expect(_trailingCap(tester, 'Only on this device'), 336);
  });
}
