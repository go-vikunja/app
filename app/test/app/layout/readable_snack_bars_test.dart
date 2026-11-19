import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_snack_bars.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';

import '../../helpers/large_screens.dart';

/// Flutter's margin beside a floating snackbar.
const _margin = 15.0;

Future<void> _showSnackBar(
  WidgetTester tester,
  Widget Function(Widget scaffold) wrap,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: wrap(const Scaffold(key: ValueKey('scaffold'), body: SizedBox())),
    ),
  );
  ScaffoldMessenger.of(tester.element(find.byKey(const ValueKey('scaffold'))))
      .showSnackBar(const SnackBar(content: Text('Saved')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a large window the snackbar keeps the readable width, '
      'centred in its scaffold', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await _showSnackBar(tester, (child) => ReadableSnackBars(child: child));

    final bar = snackBarRect(tester);
    expect(bar.width, ReadableWidth.snackBar - 2 * _margin);
    expect(bar.center.dx, androidTabletLandscape.width / 2);
  });

  testWidgets('the window form takes the width of the window', (tester) async {
    useWindow(tester, androidTabletPortrait);
    await _showSnackBar(
      tester,
      (child) => ReadableSnackBars.window(child: child),
    );

    final bar = snackBarRect(tester);
    expect(bar.width, ReadableWidth.snackBar - 2 * _margin);
    expect(bar.center.dx, androidTabletPortrait.width / 2);
  });

  testWidgets('a scaffold no wider than the readable width inside a wider '
      'one keeps Flutter margins, not the width set around it', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await _showSnackBar(
      tester,
      (child) => ReadableSnackBars.window(
        child: Align(
          alignment: Alignment.topRight,
          child: SizedBox(width: 480, child: ReadableSnackBars(child: child)),
        ),
      ),
    );

    final bar = snackBarRect(tester);
    final scaffold = tester.getRect(find.byKey(const ValueKey('scaffold')));
    expect(bar.left, scaffold.left + _margin);
    expect(bar.right, scaffold.right - _margin);
  });

  for (final size in [
    androidPhone,
    const Size(412, 915),
    defaultSurface,
    androidLandscape,
  ]) {
    testWidgets('at ${sizeName(size)} the snackbar spans the window less '
        "Flutter's margins, as before", (tester) async {
      useWindow(tester, size);
      await _showSnackBar(
        tester,
        (child) =>
            ReadableSnackBars.window(child: ReadableSnackBars(child: child)),
      );

      final bar = snackBarRect(tester);
      expect(bar.left, _margin);
      expect(bar.right, size.width - _margin);
    });
  }
}
