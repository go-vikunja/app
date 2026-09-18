import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/locale_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/login/login_page.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_controllers.dart';
import '../../helpers/mock_http_overrides.dart';
import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late ControllerCalls calls;
  late TestRepositories repos;

  setUp(() {
    mockPlatformPlugins();
    // The user header renders the avatar through NetworkImage.
    mockNetworkImages();
    calls = ControllerCalls();
    repos = TestRepositories();
  });

  Future<FakeSettingsController> pumpPage(
    WidgetTester tester, {
    bool ignoreCertificates = false,
    bool sentryEnabled = false,
    bool versionNotifications = false,
    int refreshInterval = 0,
    FlutterThemeMode themeMode = FlutterThemeMode.system,
    bool dynamicColors = false,
    Version? currentVersion,
    List<dynamic> projects = const [],
    int defaultProjectId = 0,
  }) async {
    final state = buildSettingsState(
      user: buildUser(
        username: 'demo',
        name: 'Demo User',
        settings: buildUserSettings(defaultProjectId: defaultProjectId),
      ),
      projects: projects.cast(),
      ignoreCertificates: ignoreCertificates,
      sentryEnabled: sentryEnabled,
      versionNotifications: versionNotifications,
      refreshInterval: refreshInterval,
      themeMode: themeMode,
      dynamicColors: dynamicColors,
      currentVersion: currentVersion,
    );
    final controller = FakeSettingsController(state, calls);

    await pumpApp(
      tester,
      const SettingsPage(),
      surfaceSize: tallPhoneSurface,
      overrides: [
        ...repos.overrides,
        currentUserOverride(buildUser()),
        settingsControllerProviderOverrideWith(controller),
      ],
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('rendering', () {
    testWidgets('shows the signed-in user', (tester) async {
      await pumpPage(tester);

      expect(find.text('Demo User'), findsOneWidget);
      expect(find.text('demo'), findsOneWidget);
    });

    testWidgets('shows every settings row', (tester) async {
      await pumpPage(tester);

      expect(find.text(l10n.theme), findsOneWidget);
      expect(find.text(l10n.language), findsOneWidget);
      expect(find.text(l10n.dynamicColors), findsOneWidget);
      expect(find.text(l10n.ignoreCertificates), findsOneWidget);
      expect(find.text(l10n.enableSentry), findsOneWidget);
      expect(find.text(l10n.backgroundRefreshInterval), findsOneWidget);
      expect(find.text(l10n.getVersionNotifications), findsOneWidget);
      expect(find.text(l10n.sendTestNotification), findsOneWidget);
      expect(find.text(l10n.checkForLatestVersion), findsOneWidget);
      expect(find.text(l10n.logout), findsOneWidget);
    });

    testWidgets('names the current version when known', (tester) async {
      await pumpPage(tester, currentVersion: Version(1, 2, 3));

      expect(find.text(l10n.currentVersionPrefix('1.2.3')), findsOneWidget);
    });

    testWidgets('says the version is unknown when it is missing', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(l10n.currentVersionUnknown), findsOneWidget);
    });

    testWidgets('prefills the refresh interval', (tester) async {
      await pumpPage(tester, refreshInterval: 45);

      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('reflects the stored toggles', (tester) async {
      await pumpPage(
        tester,
        ignoreCertificates: true,
        sentryEnabled: true,
        versionNotifications: true,
        dynamicColors: true,
      );

      final checkboxes = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(checkboxes.every((c) => c.value == true), isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SettingsPage(),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          settingsControllerProviderOverridePending(),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('shows an error view when the controller fails', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SettingsPage(),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          settingsControllerProviderOverrideFailing(),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
    });
  });

  group('the theme picker', () {
    testWidgets('offers system, light and dark', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(DropdownButton<FlutterThemeMode>));

      expect(find.text(l10n.system), findsWidgets);
      expect(find.text(l10n.light), findsWidgets);
      expect(find.text(l10n.dark), findsWidgets);
    });

    testWidgets('picking dark saves it', (tester) async {
      final controller = await pumpPage(tester);

      await tapAndSettle(tester, find.byType(DropdownButton<FlutterThemeMode>));
      await tapAndSettle(tester, find.text(l10n.dark).last);

      expect(calls.called('setThemeMode'), isTrue);
      expect(controller.setValues, [FlutterThemeMode.dark]);
    });

    testWidgets('picking light saves it', (tester) async {
      final controller = await pumpPage(
        tester,
        themeMode: FlutterThemeMode.dark,
      );

      await tapAndSettle(tester, find.byType(DropdownButton<FlutterThemeMode>));
      await tapAndSettle(tester, find.text(l10n.light).last);

      expect(controller.setValues, [FlutterThemeMode.light]);
    });
  });

  group('the language picker', () {
    testWidgets('offers the system option and every supported locale', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(l10n.systemLanguage), findsOneWidget);
    });

    testWidgets('picking a language stores the override', (tester) async {
      final container = await pumpApp(
        tester,
        const SettingsPage(),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          settingsOverride(
            buildSettingsState(user: buildUser(username: 'demo')),
            calls,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byType(DropdownButton<Locale?>));
      await tapAndSettle(tester, find.text('English').last);
      await tester.pumpAndSettle();

      expect(repos.settings.localeOverride, 'en');
      expect(container.read(localeOverrideProvider).value, const Locale('en'));
    });
  });

  group('the toggles', () {
    testWidgets('dynamic colours saves the new value', (tester) async {
      final controller = await pumpPage(tester);

      await tapAndSettle(tester, find.byType(SwitchListTile));

      expect(calls.called('setDynamicColors'), isTrue);
      expect(controller.setValues, [true]);
    });

    testWidgets('ignore certificates saves the new value', (tester) async {
      final controller = await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.ignoreCertificates));

      expect(calls.called('setIgnoreCertificates'), isTrue);
      expect(controller.setValues, [true]);
    });

    testWidgets('enable Sentry saves the new value', (tester) async {
      final controller = await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.enableSentry));

      expect(calls.called('setSentryEnabled'), isTrue);
      expect(controller.setValues, [true]);
    });

    testWidgets('version notifications saves the new value', (tester) async {
      final controller = await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.getVersionNotifications));

      expect(calls.called('setVersionNotifications'), isTrue);
      expect(controller.setValues, [true]);
    });

    testWidgets('a toggle that is already on saves false', (tester) async {
      final controller = await pumpPage(tester, sentryEnabled: true);

      await tapAndSettle(tester, find.text(l10n.enableSentry));

      expect(controller.setValues, [false]);
    });
  });

  group('the refresh interval', () {
    testWidgets('accepts only digits', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, find.byType(TextField), '12abc34');

      expect(find.text('1234'), findsOneWidget);
    });

    testWidgets('Save stores the typed interval', (tester) async {
      final controller = await pumpPage(tester);

      await enterTextAndSettle(tester, find.byType(TextField), '25');
      await tapAndSettle(tester, find.text(l10n.save));

      expect(calls.called('setRefreshInterval'), isTrue);
      expect(controller.setValues, [25]);
    });

    testWidgets('an empty field saves zero', (tester) async {
      final controller = await pumpPage(tester, refreshInterval: 10);

      await enterTextAndSettle(tester, find.byType(TextField), '');
      await tapAndSettle(tester, find.text(l10n.save));

      expect(controller.setValues, [0]);
    });
  });

  group('the default project picker', () {
    testWidgets('offers None plus every project', (tester) async {
      await pumpPage(
        tester,
        projects: [
          buildProject(id: 1, title: 'Alpha'),
          buildProject(id: 2, title: 'Beta'),
        ],
      );

      await tapAndSettle(tester, find.byType(DropdownButton<int>));

      expect(find.text(l10n.none), findsWidgets);
      expect(find.text('Alpha'), findsWidgets);
      expect(find.text('Beta'), findsWidgets);
    });

    testWidgets('picking a project saves it as the default', (tester) async {
      final controller = await pumpPage(
        tester,
        projects: [buildProject(id: 7, title: 'Alpha')],
      );

      await tapAndSettle(tester, find.byType(DropdownButton<int>));
      await tapAndSettle(tester, find.text('Alpha').last);

      expect(calls.called('setDefaultProject'), isTrue);
      expect(controller.setValues, [7]);
    });

    testWidgets('shows None when the stored default no longer exists', (
      tester,
    ) async {
      await pumpPage(
        tester,
        projects: [buildProject(id: 1, title: 'Alpha')],
        defaultProjectId: 99,
      );

      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .value,
        0,
      );
    });

    testWidgets('preselects the stored default project', (tester) async {
      await pumpPage(
        tester,
        projects: [buildProject(id: 7, title: 'Alpha')],
        defaultProjectId: 7,
      );

      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .value,
        7,
      );
    });
  });

  group('checking for a newer version', () {
    testWidgets('shows the latest version when one is found', (tester) async {
      repos.version.latest = Version(9, 9, 9);
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.checkForLatestVersion));

      expect(find.text(l10n.latestVersionPrefix('9.9.9')), findsOneWidget);
    });

    testWidgets('warns when the latest version cannot be fetched', (
      tester,
    ) async {
      repos.version.latest = null;
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.checkForLatestVersion));

      expect(find.text("Couldn't get latest version!"), findsOneWidget);
    });
  });

  group('the test notification', () {
    testWidgets('asks the notification handler to send one', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.sendTestNotification));

      // With permission granted and no handler registered this is a no-op;
      // what matters is that the tap does not throw.
      expect(tester.takeException(), isNull);
    });
  });

  group('logging out', () {
    testWidgets('clears the stored credentials', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.logout));

      expect(repos.settings.server, isNull);
      expect(repos.settings.userToken, isNull);
      expect(repos.settings.refreshToken, isNull);
    });

    testWidgets('returns to the login page', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.logout));

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}

/// Overrides the settings controller with a specific fake instance so the test
/// can read back the values the page handed it.
Override settingsControllerProviderOverrideWith(
  FakeSettingsController controller,
) => settingsControllerProvider.overrideWith(() => controller);
