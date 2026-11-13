import 'dart:async';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late SyncFakes data;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
  });

  FakeAccountSettingsRepository repository() => data.shared.accountSettings;

  void useSystemPalette(WidgetTester tester) {
    final palette = Int64List.fromList([
      for (var tone = 0; tone < 5 * 13; tone++) 0xFF000000 + tone * 0x030303,
    ]);
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        DynamicColorPlugin.channel,
        (call) async =>
            call.method == DynamicColorPlugin.methodName ? palette : null,
      );
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(DynamicColorPlugin.channel, null),
    );
  }

  Finder tabList() => find
      .descendant(
        of: find.byType(AccountTab),
        matching: find.byType(Scrollable),
      )
      .first;

  /// The Appearance section's header ends up at the top of the screen.
  Future<void> scrollToAppearance(
    WidgetTester tester, [
    AppLocalizations? l10n,
  ]) async {
    await tester.scrollUntilVisible(
      find.text((l10n ?? en).appearanceHeading),
      100,
      scrollable: tabList(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAccountTab(
    WidgetTester tester, {
    bool needsReauth = false,
    bool language = false,
    Size size = phoneSize,
  }) async {
    usePhoneSurface(tester, logicalSize: size);
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: needsReauth,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [
        if (language)
          appLanguageSettingsAvailableProvider.overrideWith(
            (ref) async => true,
          ),
      ],
    );
    await openTab(tester, en.tabAccount);
    await scrollToAppearance(tester);
  }

  final segments = find.byType(SegmentedButton<ThemeMode>);

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AccountTab))).brightness;

  void expectNothingSent() {
    expect(repository().changes, isEmpty);
    expect(
      repository().calls.where((call) => call.startsWith('update')),
      isEmpty,
    );
  }

  testWidgets('the theme applies at once, side by side, is stored on this '
      'device and sends nothing to the server', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAccountTab(tester);

    expect(
      tester.getSemantics(find.text(en.appearanceThemeSystem)),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    expect(brightness(tester), Brightness.light);
    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text(en.appearanceThemeDark)),
      isSemantics(isSelected: true),
    );
    expect(brightness(tester), Brightness.dark);
    expect(auth.preferences.values[themeModeKey], 'dark');
    expectNothingSent();
    semantics.dispose();
  });

  testWidgets('a stored theme shows as chosen', (tester) async {
    auth.preferences.values[themeModeKey] = 'dark';
    await pumpAccountTab(tester);

    expect(tester.widget<SegmentedButton<ThemeMode>>(segments).selected, {
      ThemeMode.dark,
    });
    expect(brightness(tester), Brightness.dark);
  });

  testWidgets('each row says it stays on this device, and the section has '
      'no device mark', (tester) async {
    useSystemPalette(tester);
    await pumpAccountTab(tester, language: true, size: const Size(360, 1000));

    final header = find.widgetWithText(ListSectionHeader, en.appearanceHeading);
    expect(
      find.descendant(of: header, matching: find.text(en.onThisDeviceHeading)),
      findsNothing,
    );
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final theme = find.text(en.appearanceTheme);
    final themeLine = find.text(en.appearanceOnThisDevice).first;
    expect(top(themeLine), greaterThan(top(theme)));
    expect(top(themeLine), lessThan(top(segments)));
    for (final row in [
      find.widgetWithText(SwitchListTile, en.appearanceSystemColors),
      find.widgetWithText(ListTile, en.appLanguageTitle),
    ]) {
      expect(
        find.descendant(
          of: row,
          matching: find.text(en.appearanceOnThisDevice),
        ),
        findsOneWidget,
      );
    }
    expect(find.text(en.appearanceOnThisDevice), findsNWidgets(3));
  });

  testWidgets('the chosen theme carries a check where the segments have room '
      'for their icons', (tester) async {
    await pumpAccountTab(tester, size: const Size(600, 740));

    Finder inSegmentOf(String label, Finder matching) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      ),
      matching: matching,
    );
    expect(
      inSegmentOf(en.appearanceThemeSystem, find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      inSegmentOf(
        en.appearanceThemeLight,
        find.byIcon(Icons.light_mode_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.brightness_auto_outlined), findsNothing);
    final section = find.ancestor(
      of: segments,
      matching: find.byType(SettingsSection),
    );
    expect(
      tester.getSize(segments).width,
      moreOrLessEquals(tester.getSize(section).width - 32, epsilon: 1),
    );
  });

  testWidgets('on iOS in a sliding segmented control; the same choice again '
      'stores nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAccountTab(tester);

    Finder segment(String label) => find.descendant(
      of: find.byType(CupertinoSlidingSegmentedControl<ThemeMode>),
      matching: find.text(label),
    );
    expect(segments, findsNothing);
    final system = tester.getSemantics(segment(en.appearanceThemeSystem));
    expect(
      system,
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    // A tap on the chosen segment does nothing; only VoiceOver's
    // activation reports it again.
    system.owner!.performAction(system.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(auth.preferences.values.containsKey(themeModeKey), isFalse);

    await tester.tap(segment(en.appearanceThemeDark));
    await tester.pumpAndSettle();
    expect(auth.preferences.values[themeModeKey], 'dark');
    expect(brightness(tester), Brightness.dark);
    expectNothingSent();
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('can be changed', () {
    Future<void> pickDark(WidgetTester tester) async {
      expect(
        tester.widget<SegmentedButton<ThemeMode>>(segments).onSelectionChanged,
        isNotNull,
      );
      await tester.tap(find.text(en.appearanceThemeDark));
      // The theme animates; a spinner elsewhere keeps it from settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(brightness(tester), Brightness.dark);
      expect(auth.preferences.values[themeModeKey], 'dark');
    }

    testWidgets('offline', (tester) async {
      data = SyncFakes(
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final semantics = tester.ensureSemantics();
      await pumpAccountTab(tester);
      expect(
        tester.getSemantics(find.text(en.appearanceThemeDark)),
        isSemantics(hasEnabledState: true, isEnabled: true),
      );

      await pickDark(tester);
      await tester.pumpAndSettle();
      expectNothingSent();
      semantics.dispose();
    });

    testWidgets('while a new sign-in is needed', (tester) async {
      await pumpAccountTab(tester, needsReauth: true);

      await pickDark(tester);
    });

    testWidgets('while signing out', (tester) async {
      final release = Completer<void>();
      auth.secureStore.beforeDelete = (_) => release.future;
      await pumpAccountTab(tester);

      final signOut = find.widgetWithText(OutlinedButton, en.homeSignOut);
      await tester.scrollUntilVisible(signOut, 100, scrollable: tabList());
      await tester.pump();
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(en.homeSigningOut), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(en.appearanceHeading),
        -100,
        scrollable: tabList(),
      );
      await tester.pump();

      await pickDark(tester);

      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(ConnectServerScreen))).brightness,
        Brightness.dark,
      );
    });
  });

  testWidgets('a guest gets the theme of this device too, beside the device '
      'rows', (tester) async {
    useSystemPalette(tester);
    usePhoneSurface(tester);
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabAccount);
    await scrollToAppearance(tester);

    expect(
      find.widgetWithText(SwitchListTile, en.appearanceSystemColors),
      findsOneWidget,
    );
    expect(find.text(en.appearanceTheme), findsOneWidget);
    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pumpAndSettle();

    expect(brightness(tester), Brightness.dark);
    expect(auth.preferences.values[themeModeKey], 'dark');
  });

  testWidgets('a guest with neither a palette nor the language row keeps the '
      'Appearance section for the theme', (tester) async {
    usePhoneSurface(tester);
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabAccount);
    await scrollToAppearance(tester);

    expect(find.text(en.appearanceTheme), findsOneWidget);
    expect(segments, findsOneWidget);
    expect(find.text(en.appearanceSystemColors), findsNothing);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    usePhoneSurface(tester);
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(tester, auth: auth, sync: data);
    await openTab(tester, de.tabAccount);
    await scrollToAppearance(tester, de);

    expect(find.text(de.appearanceTheme), findsOneWidget);
    expect(find.text(de.appearanceOnThisDevice), findsOneWidget);
    for (final label in [
      de.appearanceThemeLight,
      de.appearanceThemeSystem,
      de.appearanceThemeDark,
    ]) {
      expect(
        find.descendant(of: segments, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });
}
