import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';
import 'package:vikunja_mobile/features/connection/presentation/secret_text_field.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/app_lock_fakes.dart';
import '../../helpers/pump_app.dart';

// iOS cannot keep the window out of a recording or a mirrored display, so a
// secret on screen hides itself while the screen is captured.
void main() {
  const secret = 'tk_00000000000000000000000000000000000000c7';
  late FakeSecureWindow window;
  late FakeSensitiveClipboard clipboard;

  setUp(() {
    window = FakeSecureWindow(capturable: true);
    clipboard = FakeSensitiveClipboard();
  });

  void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
      states.forEach(tester.binding.handleAppLifecycleStateChanged);

  Future<void> pumpScreen(WidgetTester tester, Widget body) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureWindowProvider.overrideWithValue(window),
            sensitiveClipboardProvider.overrideWithValue(clipboard),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(body: body),
          ),
        ),
      );

  group('a new token', () {
    Future<void> pumpToken(WidgetTester tester) => pumpScreen(
      tester,
      const OneTimeSecretView(secret: secret, title: 'Title', usage: 'Usage'),
    );

    double tokenOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(secret), matching: find.byType(Opacity)),
        )
        .opacity;

    testWidgets('is invisible until iOS says the screen is not captured', (
      tester,
    ) async {
      await pumpToken(tester);
      expect(window.secure, isTrue);
      expect(tokenOpacity(tester), 0);

      await tester.pump();

      expect(tokenOpacity(tester), 1);
      expect(find.text(en.secretHiddenWhileCaptured), findsNothing);
    });

    testWidgets('gives way to a note while the screen is captured, and can '
        'still be copied', (tester) async {
      window.captured = true;
      await pumpToken(tester);
      await tester.pump();

      expect(find.text(secret), findsNothing);
      expect(find.text(en.secretHiddenWhileCaptured), findsOneWidget);
      await tester.tap(find.text(en.oneTimeSecretCopy));
      await tester.pump();
      expect(clipboard.copied, [secret]);

      window.setCaptured(false);
      await tester.pump();
      expect(find.text(secret), findsOneWidget);
      expect(tokenOpacity(tester), 1);
      expect(find.text(en.secretHiddenWhileCaptured), findsNothing);

      window.setCaptured(true);
      await tester.pump();
      expect(find.text(secret), findsNothing);
    });

    testWidgets('shows at once where the window keeps out of captures', (
      tester,
    ) async {
      window = FakeSecureWindow();

      await pumpToken(tester);

      expect(tokenOpacity(tester), 1);
    });

    // Out of the app switcher's snapshot, which a capture started while
    // the app is away would show.
    testWidgets('is invisible as soon as the app leaves, and again only '
        'once iOS has said after the return that the screen is not '
        'captured', (tester) async {
      lifecycle(tester, const [AppLifecycleState.resumed]);
      await pumpToken(tester);
      await tester.pump();
      expect(tokenOpacity(tester), 1);

      lifecycle(tester, const [AppLifecycleState.inactive]);
      await tester.pump();
      expect(tokenOpacity(tester), 0);
      expect(find.text(en.secretHiddenWhileCaptured), findsNothing);

      lifecycle(tester, const [AppLifecycleState.resumed]);
      expect(window.changes, [true, true]);
      expect(tokenOpacity(tester), 0);
      await tester.pump();
      await tester.pump();
      expect(tokenOpacity(tester), 1);
    });

    testWidgets('gives way to the note when the app comes back while the '
        'screen is captured', (tester) async {
      lifecycle(tester, const [AppLifecycleState.resumed]);
      await pumpToken(tester);
      await tester.pump();

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      // Started while the app was away, and never reported.
      window.captured = true;
      lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();

      expect(find.text(secret), findsNothing);
      expect(find.text(en.secretHiddenWhileCaptured), findsOneWidget);
    });
  });

  group('a revealed secret field', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController(text: 'value'));
    tearDown(() => controller.dispose());

    Future<void> pumpField(WidgetTester tester) => pumpScreen(
      tester,
      SecretTextField(
        controller: controller,
        label: 'Value',
        revealTooltip: 'Show',
        hideTooltip: 'Hide',
        helperText: 'Helper',
      ),
    );

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    testWidgets('is masked again while the screen is captured, and says '
        'why', (tester) async {
      window.captured = true;
      await pumpField(tester);
      expect(field(tester).obscureText, isTrue);
      expect(find.text(en.secretHiddenWhileCaptured), findsNothing);

      await tester.tap(find.byTooltip('Show'));
      await tester.pump();
      await tester.pump();
      expect(window.secure, isTrue);
      expect(field(tester).obscureText, isTrue);
      expect(find.text(en.secretHiddenWhileCaptured), findsOneWidget);
      expect(find.text('Helper'), findsNothing);

      window.setCaptured(false);
      await tester.pump();
      expect(field(tester).obscureText, isFalse);
      expect(find.text(en.secretHiddenWhileCaptured), findsNothing);
      expect(find.text('Helper'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide'));
      await tester.pump();
      expect(window.secure, isFalse);
      expect(field(tester).obscureText, isTrue);
    });

    testWidgets('is masked while the app is away', (tester) async {
      lifecycle(tester, const [AppLifecycleState.resumed]);
      await pumpField(tester);
      await tester.tap(find.byTooltip('Show'));
      await tester.pump();
      await tester.pump();
      expect(field(tester).obscureText, isFalse);

      lifecycle(tester, const [AppLifecycleState.inactive]);
      await tester.pump();
      expect(field(tester).obscureText, isTrue);
      expect(find.text('Helper'), findsOneWidget);

      lifecycle(tester, const [AppLifecycleState.resumed]);
      await tester.pump();
      await tester.pump();
      expect(field(tester).obscureText, isFalse);
    });
  });
}
