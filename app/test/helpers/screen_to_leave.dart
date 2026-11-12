import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A screen of its own over the app. A sheet opened from its [context]
/// stays when [leave] takes the screen away, as one opened from the pane
/// does when the window narrows.
final class ScreenToLeave {
  new _(this._route, this.context);

  final ModalRoute<void> _route;
  final BuildContext context;

  static Future<ScreenToLeave> push(WidgetTester tester) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: SizedBox.expand()),
    );
    Navigator.of(
      tester.element(find.byType(Scaffold).first),
      rootNavigator: true,
    ).push(route);
    await tester.pumpAndSettle();
    return ScreenToLeave._(route, route.subtreeContext!);
  }

  Future<void> leave(WidgetTester tester) async {
    _route.navigator!.removeRoute(_route);
    await tester.pumpAndSettle();
    expect(context.mounted, isFalse);
  }
}
