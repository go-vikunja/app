import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_app_bar.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';

import '../../helpers/large_screens.dart';

typedef _Places = ({double back, double title, double search, double root});

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Widget page(String title) => Scaffold(
    appBar: ReadableAppBar(
      maxWidth: ReadableWidth.list,
      title: Text(title),
      actions: [
        IconButton(
          onPressed: () {},
          tooltip: 'Search',
          icon: const Icon(Icons.search),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: SizedBox(
          key: ValueKey('bottom'),
          width: double.infinity,
          height: 4,
        ),
      ),
    ),
  );

  /// From [start] and [end]: the back button's start, a pushed page's title
  /// start, the action's end and the first page's title start.
  Future<_Places> placesIn(
    WidgetTester tester, {
    required double start,
    required double end,
  }) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: page('Upcoming')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page('Work')),
    );
    await tester.pumpAndSettle();
    final back = tester.getRect(find.byType(BackButton)).left - start;
    final title = tester.getTopLeft(find.text('Work')).dx - start;
    final search = end - tester.getRect(find.byTooltip('Search')).right;
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    final root = tester.getTopLeft(find.text('Upcoming')).dx - start;
    return (back: back, title: title, search: search, root: root);
  }

  testWidgets('on a tablet the back button, the title and the action sit '
      "at the band's edges where a phone has them at the window's, while "
      'the bar and its bottom take the whole width', (tester) async {
    useWindow(tester, androidPhone);
    final phone = await placesIn(tester, start: 0, end: androidPhone.width);
    expect(phone.title, kToolbarHeight + NavigationToolbar.kMiddleSpacing);
    expect(phone.root, NavigationToolbar.kMiddleSpacing);

    useWindow(tester, androidTabletLandscape);
    const band = (left: 220.0, right: 1060.0);
    final tablet = await placesIn(tester, start: band.left, end: band.right);

    expect(tablet, phone);
    expect(tester.getRect(find.byType(AppBar)).width, 1280);
    expect(tester.getRect(find.byKey(const ValueKey('bottom'))).width, 1280);
  });
}
