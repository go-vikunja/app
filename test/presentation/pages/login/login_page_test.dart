import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/presentation/pages/login/login_page.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_repositories.dart';
import '../../../helpers/plugin_mocks.dart';
import '../../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late TestRepositories repos;
  late FakeUrlLauncher urlLauncher;

  setUp(() {
    mockPlatformPlugins();
    // A failed browser launch ends the OAuth step immediately; the real flow
    // would sit waiting ten minutes for a deep-link callback.
    urlLauncher = mockUrlLauncher();
    repos = TestRepositories();
    // The sentry consent dialog is a one-time prompt; most tests want it gone.
    repos.settings.sentryDialogShown = true;
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpApp(tester, const LoginPage(), overrides: repos.overrides);
    await tester.pumpAndSettle();
  }

  group('the landing view', () {
    testWidgets('offers the cloud, demo and custom-server buttons', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(l10n.vikunjaCloud), findsOneWidget);
      expect(find.text(l10n.tryDemo), findsOneWidget);
      expect(find.text(l10n.customServerUrl), findsOneWidget);
    });

    testWidgets('shows the logo', (tester) async {
      await pumpPage(tester);

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('hides the server field until asked for', (tester) async {
      await pumpPage(tester);

      expect(find.text(l10n.serverAddress), findsNothing);
    });

    testWidgets('clears any stored credentials on arrival', (tester) async {
      repos.settings
        ..userToken = 'stale'
        ..refreshToken = 'stale';

      await pumpPage(tester);

      // LoginPage clears through its own datasource, so assert on the store.
      expect(mockSecureStorage['user-token'], isNull);
      expect(mockSecureStorage['refresh-token'], isNull);
    });
  });

  group('the sentry consent prompt', () {
    testWidgets('is shown the first time the login page opens', (tester) async {
      repos.settings.sentryDialogShown = false;

      await pumpPage(tester);

      expect(find.byType(SentryDialog), findsOneWidget);
    });

    testWidgets('is not shown again once it has been answered', (tester) async {
      repos.settings.sentryDialogShown = true;

      await pumpPage(tester);

      expect(find.byType(SentryDialog), findsNothing);
    });

    testWidgets('accepting turns error reporting on', (tester) async {
      repos.settings
        ..sentryDialogShown = false
        ..sentryEnabled = false;
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.yes));

      expect(repos.settings.sentryEnabled, isTrue);
    });

    testWidgets('declining turns error reporting off', (tester) async {
      repos.settings
        ..sentryDialogShown = false
        ..sentryEnabled = true;
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.no));

      expect(repos.settings.sentryEnabled, isFalse);
    });

    testWidgets('answering it records that it was shown', (tester) async {
      repos.settings.sentryDialogShown = false;

      await pumpPage(tester);

      expect(repos.settings.sentryDialogShown, isTrue);
    });
  });

  group('the custom server form', () {
    testWidgets('opens when the custom-server button is tapped', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));

      expect(find.text(l10n.serverAddress), findsOneWidget);
      expect(find.text(l10n.loginServerExplanation), findsOneWidget);
    });

    testWidgets('offers the ignore-certificates checkbox', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));

      expect(find.text(l10n.ignoreCertificates), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('ticking ignore-certificates stores the choice', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await tapAndSettle(tester, find.byType(Checkbox));

      expect(repos.settings.ignoreCertificates, isTrue);
    });

    testWidgets('cancel returns to the landing view', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(find.text(l10n.serverAddress), findsNothing);
      expect(find.text(l10n.vikunjaCloud), findsOneWidget);
    });

    testWidgets('an empty address does not attempt a connection', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await tapAndSettle(tester, find.text(l10n.login));

      expect(repos.server.getInfoCount, 0);
    });
  });

  group('connecting to a server', () {
    testWidgets('an unreachable server is reported on the field', (
      tester,
    ) async {
      repos.server.onGetInfo = () => err<Server>();
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(find.text(l10n.cannotReachServer), findsOneWidget);
    });

    testWidgets('an unreachable server is not saved', (tester) async {
      repos.settings.server = null;
      repos.server.onGetInfo = () => err<Server>();
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(repos.settings.server, isNull);
      expect(repos.settings.pastServers, isEmpty);
    });

    testWidgets('a reachable server is saved and remembered', (tester) async {
      repos.settings
        ..server = null
        ..pastServers = [];
      repos.server.onGetInfo = () => ok(buildServer(version: 'v2.4.0'));
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(repos.settings.server, 'https://vikunja.example.com');
      expect(repos.settings.pastServers, ['https://vikunja.example.com']);
    });

    testWidgets('normalises the address before saving it', (tester) async {
      repos.settings
        ..server = null
        ..pastServers = [];
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'vikunja.example.com/api/v1/',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(repos.settings.server, 'https://vikunja.example.com');
    });

    testWidgets('publishes the address so the client can be built', (
      tester,
    ) async {
      repos.server.onGetInfo = () => ok(buildServer());
      final container = await pumpApp(
        tester,
        const LoginPage(),
        overrides: repos.overrides,
      );
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(
        container.read(authDataProvider)!.address,
        'https://vikunja.example.com',
      );
    });

    testWidgets('warns when the server is too old', (tester) async {
      repos.server.onGetInfo = () => ok(buildServer(version: 'v0.1.0'));
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tester.tap(find.text(l10n.login));
      await tester.pump();
      await tester.pump();

      expect(find.byType(VersionMismatchDialog), findsOneWidget);
    });

    testWidgets('does not warn for a supported server', (tester) async {
      repos.server.onGetInfo = () => ok(buildServer(version: 'v2.3.0'));
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tester.tap(find.text(l10n.login));
      await tester.pump();
      await tester.pump();

      expect(find.byType(VersionMismatchDialog), findsNothing);
    });
  });

  group('the oauth step', () {
    testWidgets('opens the authorize url in a browser', (tester) async {
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(
        urlLauncher.launched.single,
        startsWith('https://vikunja.example.com/oauth/authorize'),
      );
    });

    testWidgets('sends the pkce challenge and a state parameter', (
      tester,
    ) async {
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      final query = Uri.parse(urlLauncher.launched.single).queryParameters;
      expect(query['response_type'], 'code');
      expect(query['client_id'], 'vikunja-flutter');
      expect(query['redirect_uri'], 'vikunja-flutter://callback');
      expect(query['code_challenge_method'], 'S256');
      expect(query['code_challenge'], isNotEmpty);
      expect(query['state'], isNotEmpty);
    });

    testWidgets('reports a failed browser launch', (tester) async {
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(find.text(l10n.oauthBrowserLaunchFailed), findsOneWidget);
    });

    testWidgets('re-enables the login button afterwards', (tester) async {
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.customServerUrl));
      await enterTextAndSettle(
        tester,
        find.byType(TextFormField),
        'https://vikunja.example.com',
      );
      await tapAndSettle(tester, find.text(l10n.login));

      expect(find.text(l10n.login), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the preset servers', () {
    testWidgets('Vikunja Cloud connects to the cloud address', (tester) async {
      repos.settings.server = null;
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.vikunjaCloud));

      expect(repos.settings.server, 'https://app.vikunja.cloud');
    });

    testWidgets('Try demo connects to the demo address', (tester) async {
      repos.settings.server = null;
      repos.server.onGetInfo = () => ok(buildServer());
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.tryDemo));

      expect(repos.settings.server, 'https://try.vikunja.io');
    });

    testWidgets('an unreachable preset leaves the server unsaved', (
      tester,
    ) async {
      repos.settings.server = null;
      repos.server.onGetInfo = () => err<Server>();
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.vikunjaCloud));

      expect(repos.settings.server, isNull);
    });
  });
}
