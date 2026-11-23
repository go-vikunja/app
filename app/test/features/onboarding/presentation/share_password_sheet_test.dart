import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/share_password_sheet.dart';

import '../../../helpers/announcer_region.dart';
import '../../../helpers/pump_app.dart';

void main() {
  /// Every password is wrong; the answer comes after [answerAfter].
  Future<void> pumpSheet(WidgetTester tester, Duration answerAfter) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => AnnouncerHost(child: child!),
        home: Scaffold(
          body: SharePasswordSheet(
            serverRoot: Uri.parse('https://tasks.example.org/vikunja'),
            submit: (_, {required remember}) =>
                Future.delayed(answerAfter, () => SharePasswordOutcome.wrong),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<SpokenCount> tryPassword(WidgetTester tester) async {
    final spoken = SpokenCount(tester, en.guestPasswordWrong);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await spoken.frames();
    return spoken;
  }

  for (final platformAnnounces in [true, false]) {
    final how = platformAnnounces
        ? 'where the platform announces'
        : 'where it cannot, as on Android';
    // Within the error's 167 ms fade, and after it.
    for (final answerAfter in const [
      Duration.zero,
      Duration(milliseconds: 400),
    ]) {
      testWidgets('$how, a wrong password is said once, and once again for '
          'the same password tried again (answer after '
          '${answerAfter.inMilliseconds} ms)', (tester) async {
        if (!platformAnnounces) useLiveRegionAnnouncements(tester);
        await pumpSheet(tester, answerAfter);
        await tester.enterText(find.byType(TextField), 'nope');

        final first = await tryPassword(tester);
        expect(find.text(en.guestPasswordWrong), findsOneWidget);
        expect(first.times, 1);
        // The field's error, not the announcer, says a note that appears.
        expect(first.byOtherLiveRegions, platformAnnounces ? 0 : 1);

        final again = await tryPassword(tester);
        expect(again.times, 1);
        expect(again.byAnnouncerRegion, platformAnnounces ? 0 : 1);

        await tester.enterText(find.byType(TextField), 'nope2');
        await tester.pumpAndSettle();
        expect(find.text(en.guestPasswordWrong), findsNothing);
        await tester.pump(AnnouncerHost.clearAfter);
      });
    }
  }

  testWidgets('Remember starts unchecked, changes the note under the field and '
      'goes with the try', (tester) async {
    final tries = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => AnnouncerHost(child: child!),
        home: Scaffold(
          body: SharePasswordSheet(
            serverRoot: Uri.parse('https://tasks.example.org'),
            submit: (password, {required remember}) async {
              tries.add((password, remember));
              return SharePasswordOutcome.wrong;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final remember = find.widgetWithText(
      CheckboxListTile,
      en.guestPasswordRemember,
    );
    expect(tester.widget<CheckboxListTile>(remember).value, isFalse);
    expect(find.text(en.guestPasswordNotStored), findsOneWidget);
    await tester.tap(remember);
    await tester.pumpAndSettle();
    expect(find.text(en.guestPasswordRemembered), findsOneWidget);
    await tester.tap(remember);
    await tester.pumpAndSettle();
    expect(find.text(en.guestPasswordNotStored), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'first');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(remember);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tries, [('first', false), ('second', true)]);
  });

  testWidgets('dragged shut while a password is tried, an answer during the '
      'closing leaves the page below open', (tester) async {
    final answer = Completer<SharePasswordOutcome>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => AnnouncerHost(child: child!),
        home: const Scaffold(body: Text('First page')),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Second page')),
          ),
        );
    await tester.pumpAndSettle();
    final asked = askForSharePassword(
      tester.element(find.text('Second page')),
      serverRoot: Uri.parse('https://tasks.example.org'),
      submit: (_, {required remember}) => answer.future,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Past half its height closes it, with the closing still to run.
    final height = tester.getSize(find.byType(SharePasswordSheet)).height;
    await tester.drag(find.text(en.guestPasswordTitle), Offset(0, height * .7));
    await tester.pump();
    expect(find.byType(SharePasswordSheet), findsOneWidget);

    answer.complete(SharePasswordOutcome.accepted);
    await tester.pumpAndSettle();

    expect(find.byType(SharePasswordSheet), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
    expect(await asked, isNull);
  });
}
