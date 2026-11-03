/// The startup screen: it waits on the init controller and then routes to
/// login or home, warning first when the server is too old.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/init_page.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/init_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  setUp(mockPlatformPlugins);

  /// Pumps the real app shell so `globalNavigatorKey` and the named routes the
  /// page navigates to actually exist.
  /// [outcome] is a factory, not a future: an eagerly created `Future.error`
  /// counts as unhandled until Riverpod awaits it, which fails the test.
  Future<void> pumpInit(
    WidgetTester tester, {
    required Future<InitOutcome> Function() outcome,
  }) async {
    useSurfaceSize(tester, phoneSurface);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [initControllerProvider.overrideWith((ref) => outcome())],
        child: MaterialApp(
          navigatorKey: globalNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          initialRoute: '/',
          routes: {
            '/': (_) => const InitPage(),
            '/login': (_) => const Scaffold(body: Text('login screen')),
            '/home': (_) => const Scaffold(body: Text('home screen')),
          },
        ),
      ),
    );
  }

  group('while initialising', () {
    testWidgets('shows a loader', (tester) async {
      final pending = Completer<InitOutcome>();
      addTearDown(() => pending.complete(const InitGoLogin()));

      await pumpInit(tester, outcome: () => pending.future);
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });
  });

  group('when initialisation fails', () {
    testWidgets('shows an error view with retry and logout', (tester) async {
      await pumpInit(tester, outcome: () => Future.error('server exploded'));
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
      expect(find.text('server exploded'), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text(l10n.logout), findsOneWidget);
    });

    testWidgets('the logout action goes to the login screen', (tester) async {
      await pumpInit(tester, outcome: () => Future.error('server exploded'));
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text(l10n.logout));

      expect(find.text('login screen'), findsOneWidget);
    });
  });

  group('when there is no session', () {
    testWidgets('goes to the login screen', (tester) async {
      await pumpInit(tester, outcome: () => Future.value(const InitGoLogin()));
      await tester.pumpAndSettle();

      expect(find.text('login screen'), findsOneWidget);
    });

    testWidgets('says so when the login expired', (tester) async {
      await pumpInit(
        tester,
        outcome: () => Future.value(const InitGoLogin(loginExpired: true)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.loginExpiredMessage), findsOneWidget);
    });

    testWidgets('warns first when the server is too old', (tester) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoLogin(serverVersion: Version(0, 1, 0))),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VersionMismatchDialog), findsOneWidget);
      expect(find.text('login screen'), findsNothing);
    });

    testWidgets('continues to login once the warning is dismissed', (
      tester,
    ) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoLogin(serverVersion: Version(0, 1, 0))),
      );
      await tester.pump();
      await tester.pump();

      await tapAndSettle(tester, find.text(l10n.ok));

      expect(find.text('login screen'), findsOneWidget);
    });

    testWidgets('does not warn for a supported server', (tester) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoLogin(serverVersion: Version(2, 4, 0))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VersionMismatchDialog), findsNothing);
      expect(find.text('login screen'), findsOneWidget);
    });
  });

  group('when there is a session', () {
    testWidgets('goes to the home screen', (tester) async {
      await pumpInit(
        tester,
        outcome: () => Future.value(const InitGoHome(serverVersion: null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('warns first when the server is too old', (tester) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoHome(serverVersion: Version(0, 1, 0))),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VersionMismatchDialog), findsOneWidget);
      expect(find.text('home screen'), findsNothing);
    });

    testWidgets('continues home once the warning is dismissed', (tester) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoHome(serverVersion: Version(0, 1, 0))),
      );
      await tester.pump();
      await tester.pump();

      await tapAndSettle(tester, find.text(l10n.ok));

      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('does not warn for a supported server', (tester) async {
      await pumpInit(
        tester,
        outcome: () =>
            Future.value(InitGoHome(serverVersion: Version(2, 4, 0))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VersionMismatchDialog), findsNothing);
      expect(find.text('home screen'), findsOneWidget);
    });
  });
}
