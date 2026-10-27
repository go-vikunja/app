import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';

final Finder _addressField = find.byType(TextFormField);
final Finder _continueButton = find.widgetWithText(
  FilledButton,
  en.connectContinue,
);

Future<void> _submitAddress(WidgetTester tester, String address) async {
  await tester.enterText(_addressField, address);
  await tester.tap(_continueButton);
  await tester.pump();
}

void main() {
  late FakeServerConnector connector;

  setUp(() => connector = FakeServerConnector());

  testWidgets('shows the app name, the address field and the actions', (
    tester,
  ) async {
    await pumpVikunjaApp(tester, connector: connector);

    expect(find.text(en.appTitle), findsOneWidget);
    expect(find.text(en.connectTagline), findsOneWidget);
    final logo = tester.widget<Image>(
      find.descendant(
        of: find.byType(ConnectHeader),
        matching: find.byType(Image),
      ),
    );
    expect((logo.image as AssetImage).assetName, ConnectHeader.logoAsset);
    expect(logo.excludeFromSemantics, isTrue);
    expect(find.text(en.connectAddressHelper), findsOneWidget);
    expect(_continueButton, findsOneWidget);
    expect(find.text(en.connectCancel), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.url);
    expect(field.textInputAction, TextInputAction.go);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.autofillHints, [AutofillHints.url]);
  });

  testWidgets('an empty address shows an inline error and does not connect', (
    tester,
  ) async {
    await pumpVikunjaApp(tester, connector: connector);

    await _submitAddress(tester, '   ');

    expect(find.text(en.connectAddressEmpty), findsOneWidget);
    expect(connector.inputs, isEmpty);

    await tester.enterText(_addressField, 'v');
    await tester.pump();
    expect(find.text(en.connectAddressEmpty), findsNothing);
  });

  testWidgets('pressing enter submits the address', (tester) async {
    await pumpVikunjaApp(tester, connector: connector);

    await tester.enterText(_addressField, 'vikunja.example.com');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();

    expect(connector.inputs, ['vikunja.example.com']);
  });

  testWidgets('the clear button empties the field', (tester) async {
    await pumpVikunjaApp(tester, connector: connector);

    await tester.enterText(_addressField, 'tasks.example.org');
    await tester.pump();
    await tester.tap(find.byTooltip(en.connectClearAddress));
    await tester.pump();

    expect(find.text('tasks.example.org'), findsNothing);
    expect(find.byTooltip(en.connectClearAddress), findsNothing);
  });

  testWidgets('shows progress while connecting and can cancel', (tester) async {
    final pending = Completer<ServerConnection>();
    connector.handler = (_) => pending.future;
    await pumpVikunjaApp(tester, connector: connector);

    await _submitAddress(tester, ' vikunja.example.com ');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(en.connectConnectingTo('vikunja.example.com')), findsOne);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    final connectingButton = find.widgetWithText(
      FilledButton,
      en.connectConnecting,
    );
    expect(tester.widget<FilledButton>(connectingButton).onPressed, isNull);
    expect(_continueButton, findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, en.connectTryDemo),
          )
          .onPressed,
      isNull,
    );

    final cancel = find.widgetWithText(TextButton, en.connectCancel);
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();

    expect(connector.cancelTokens.single?.isCancelled, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_continueButton, findsOneWidget);
    expect(find.text(en.connectCancel), findsNothing);

    pending.complete(oauthServer230());
    await tester.pumpAndSettle();
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });

  group('a double tap does not cancel', () {
    final demoButton = find.widgetWithText(TextButton, en.connectTryDemo);
    for (final (name, button) in [
      ('Continue', _continueButton),
      ('the demo button', demoButton),
    ]) {
      // 400x1000 is tall enough that the centred content shifts when
      // connecting starts.
      for (final surface in [const Size(360, 640), const Size(400, 1000)]) {
        for (final heightFraction in [0.1, 0.5, 0.9]) {
          testWidgets('on $name at $surface, $heightFraction down', (
            tester,
          ) async {
            usePhoneSurface(tester, logicalSize: surface);
            connector.handler = (_) => Completer<ServerConnection>().future;
            await pumpVikunjaApp(tester, connector: connector);
            await tester.enterText(_addressField, 'vikunja.example.com');

            final rect = tester.getRect(button);
            final position = Offset(
              rect.center.dx,
              rect.top + rect.height * heightFraction,
            );
            await tester.tapAt(position);
            await tester.pump(const Duration(milliseconds: 150));
            await tester.tapAt(position);
            await tester.pump();

            expect(connector.inputs, hasLength(1));
            expect(connector.cancelTokens.single?.isCancelled, isFalse);
            expect(find.text(en.connectConnecting), findsOneWidget);
          });
        }
      }
    }
  });

  group('failures', () {
    final cases = <String, (Object, String, String, String)>{
      'invalid address': (
        const InvalidServerAddress('ftp://files'),
        en.failureInvalidAddressTitle,
        en.failureInvalidAddressExplanation('ftp://files'),
        en.failureInvalidAddressSuggestion,
      ),
      'unreachable': (
        ServerUnreachable(Uri.parse('https://vikunja.example.com')),
        en.failureUnreachableTitle,
        en.failureUnreachableExplanation('vikunja.example.com'),
        en.failureUnreachableSuggestion,
      ),
      'timeout': (
        ServerTimeout(Uri.parse('https://vikunja.example.com:8443')),
        en.failureTimeoutTitle,
        en.failureTimeoutExplanation('vikunja.example.com:8443'),
        en.failureTimeoutSuggestion,
      ),
      'TLS certificate': (
        TlsFailure(
          Uri.parse('https://vikunja.example.com'),
          certificateRejected: true,
        ),
        en.failureTlsTitle,
        en.failureTlsExplanation('vikunja.example.com'),
        en.connectionTlsSuggestion,
      ),
      'TLS handshake': (
        TlsFailure(Uri.parse('https://vikunja.example.com')),
        en.failureTlsTitle,
        en.failureTlsHandshakeExplanation('vikunja.example.com'),
        en.failureTlsHandshakeSuggestion,
      ),
      'not Vikunja': (
        NotAVikunjaServer(Uri.parse('https://example.com'), statusCode: 404),
        en.failureNotVikunjaTitle,
        en.failureNotVikunjaExplanation('example.com'),
        en.failureNotVikunjaSuggestion,
      ),
      'unavailable': (
        ServerUnavailable(
          Uri.parse('https://vikunja.example.com'),
          statusCode: 502,
        ),
        en.failureUnavailableTitle,
        en.failureUnavailableExplanation('vikunja.example.com'),
        en.failureUnavailableSuggestion,
      ),
      'login proxy': (
        BehindLoginProxy(Uri.parse('https://vikunja.example.com')),
        en.failureLoginProxyTitle,
        en.failureLoginProxyExplanation('vikunja.example.com'),
        en.connectionLoginProxySuggestion,
      ),
      'unexpected': (
        StateError('bug'),
        en.failureUnexpectedTitle,
        en.failureUnexpectedExplanation,
        en.failureUnexpectedSuggestion,
      ),
    };

    for (final MapEntry(
          key: name,
          value: (error, title, explanation, suggestion),
        )
        in cases.entries) {
      testWidgets('$name renders title, explanation and suggestion', (
        tester,
      ) async {
        final haptics = <MethodCall>[];
        final messenger = tester.binding.defaultBinaryMessenger
          ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
            return null;
          });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        connector.handler = (_) => Future.error(error);
        await pumpVikunjaApp(tester, connector: connector);

        await _submitAddress(tester, 'ftp://files');
        await tester.pumpAndSettle();

        final card = find.byType(ConnectionErrorCard);
        expect(card, findsOneWidget);
        for (final text in [title, explanation, suggestion]) {
          expect(
            find.descendant(of: card, matching: find.text(text)),
            findsOneWidget,
          );
        }
        expect(haptics.single.arguments, 'HapticFeedbackType.heavyImpact');
      });
    }

    testWidgets('the error card is announced as one live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      connector.handler = (_) async =>
          throw ServerUnreachable(Uri.parse('https://nope.example.com'));
      await pumpVikunjaApp(tester, connector: connector);
      await _submitAddress(tester, 'nope.example.com');
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(ConnectionErrorCard)),
        isSemantics(
          label: [
            en.failureUnreachableTitle,
            en.failureUnreachableExplanation('nope.example.com'),
            en.failureUnreachableSuggestion,
          ].join('\n'),
          isLiveRegion: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('at 200 % text the error card is scrolled into view', (
      tester,
    ) async {
      const surface = Size(320, 640);
      usePhoneSurface(tester, logicalSize: surface);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      connector.handler = (_) async =>
          throw ServerUnreachable(Uri.parse('https://nope.example.com'));
      await pumpVikunjaApp(tester, connector: connector);

      await tester.enterText(_addressField, 'nope.example.com');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      final title = find.descendant(
        of: find.byType(ConnectionErrorCard),
        matching: find.text(en.failureUnreachableTitle),
      );
      final titleRect = tester.getRect(title);
      expect(titleRect.top, greaterThanOrEqualTo(0));
      expect(titleRect.bottom, lessThanOrEqualTo(surface.height));
    });

    testWidgets('on iOS a TLS failure explains certificate trust settings', (
      tester,
    ) async {
      connector.handler = (_) async => throw TlsFailure(
        Uri.parse('https://vikunja.example.com'),
        certificateRejected: true,
      );
      await pumpVikunjaApp(tester, connector: connector);
      await _submitAddress(tester, 'vikunja.example.com');
      await tester.pumpAndSettle();

      expect(find.text(en.connectionTlsSuggestionIos), findsOneWidget);
      expect(find.text(en.connectionTlsSuggestion), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('editing the address hides the error', (tester) async {
      connector.handler = (_) async =>
          throw ServerUnreachable(Uri.parse('https://nope.example.com'));
      await pumpVikunjaApp(tester, connector: connector);
      await _submitAddress(tester, 'nope.example.com');
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionErrorCard), findsOneWidget);

      await tester.enterText(_addressField, 'yes.example.com');
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsNothing);
    });
  });

  testWidgets('a found https server opens the overview', (tester) async {
    final connection = oauthServer230();
    connector.handler = (_) async => connection;
    await pumpVikunjaApp(tester, connector: connector);

    await _submitAddress(tester, 'vikunja.example.com');
    await tester.pumpAndSettle();

    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(containerOf(tester).read(currentServerProvider), same(connection));
  });

  testWidgets('the demo button fills in the public demo and connects', (
    tester,
  ) async {
    connector.handler = (_) async =>
        fullServer270(root: 'https://try.vikunja.io', demoMode: true);
    await pumpVikunjaApp(tester, connector: connector);

    await tester.tap(find.text(en.connectTryDemo));
    await tester.pumpAndSettle();

    expect(connector.inputs, ['https://try.vikunja.io']);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(find.text(en.overviewDemoBadge), findsOneWidget);
  });

  group('plain http server', () {
    const variant = TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    });

    Future<void> connectInsecurely(WidgetTester tester) async {
      connector.handler = (_) async => insecureServer();
      await pumpVikunjaApp(tester, connector: connector);
      await _submitAddress(tester, '192.168.1.20:3456');
      await tester.pumpAndSettle();
    }

    testWidgets('asks for confirmation and continues when accepted', (
      tester,
    ) async {
      await connectInsecurely(tester);

      expect(find.text(en.insecureDialogTitle), findsOneWidget);
      expect(
        find.text(en.insecureDialogBody('192.168.1.20:3456')),
        findsOneWidget,
      );
      expect(
        debugDefaultTargetPlatformOverride == TargetPlatform.iOS
            ? find.byType(CupertinoAlertDialog)
            : find.byWidgetPredicate((widget) => widget is AlertDialog),
        findsOneWidget,
      );
      expect(containerOf(tester).read(currentServerProvider), isNull);

      await tester.tap(find.text(en.insecureDialogContinue));
      await tester.pumpAndSettle();

      expect(find.byType(ServerOverviewScreen), findsOneWidget);
      expect(find.text(en.overviewInsecureBadge), findsOneWidget);
    }, variant: variant);

    testWidgets('stays on the connect screen when declined', (tester) async {
      await connectInsecurely(tester);

      await tester.tap(find.text(en.insecureDialogCancel));
      await tester.pumpAndSettle();

      expect(find.text(en.insecureDialogTitle), findsNothing);
      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(find.byType(ServerOverviewScreen), findsNothing);
      expect(containerOf(tester).read(currentServerProvider), isNull);
      expect(find.text('192.168.1.20:3456'), findsOneWidget);
    }, variant: variant);
  });
}
