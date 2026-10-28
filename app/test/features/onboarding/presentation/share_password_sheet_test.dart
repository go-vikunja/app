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
            submit: (_) =>
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
}
