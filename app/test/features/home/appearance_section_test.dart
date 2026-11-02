import 'dart:async';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
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

  final segments = find.byType(SegmentedButton<ColorSchema>);

  ValueChanged<Set<ColorSchema>>? onSelectionChanged(WidgetTester tester) =>
      tester.widget<SegmentedButton<ColorSchema>>(segments).onSelectionChanged;

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AccountTab))).brightness;

  testWidgets('the theme is saved to the account at once, side by side, and '
      'the app follows it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAccountTab(tester);

    expect(
      tester.getSemantics(find.text(en.appearanceThemeSystem)),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    expect(
      tester.getSemantics(find.text(en.appearanceTheme)),
      isSemantics(hasEnabledState: true, isEnabled: true),
    );
    expect(brightness(tester), Brightness.light);
    tester.takeAnnouncements();
    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pumpAndSettle();

    expect(repository().changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.dark),
    ]);
    expect(
      tester.getSemantics(find.text(en.appearanceThemeDark)),
      isSemantics(isSelected: true),
    );
    expect(brightness(tester), Brightness.dark);
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.accountSettingsSaved),
    ]);
    semantics.dispose();
  });

  testWidgets('each row says where it is kept, and the section has no '
      'device mark', (tester) async {
    useSystemPalette(tester);
    await pumpAccountTab(tester, language: true, size: const Size(360, 1000));

    final header = find.widgetWithText(ListSectionHeader, en.appearanceHeading);
    expect(
      find.descendant(of: header, matching: find.text(en.onThisDeviceHeading)),
      findsNothing,
    );
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final theme = find.text(en.appearanceTheme);
    final savedToAccount = find.text(en.appearanceSavedToAccount);
    expect(savedToAccount, findsOneWidget);
    expect(top(savedToAccount), greaterThan(top(theme)));
    expect(top(savedToAccount), lessThan(top(segments)));
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
    expect(find.text(en.appearanceOnThisDevice), findsNWidgets(2));
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
      'sends nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAccountTab(tester);

    Finder segment(String label) => find.descendant(
      of: find.byType(CupertinoSlidingSegmentedControl<ColorSchema>),
      matching: find.text(label),
    );
    expect(segments, findsNothing);
    expect(
      tester.getSemantics(segment(en.appearanceThemeSystem)),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    await tester.tap(segment(en.appearanceThemeSystem));
    await tester.pumpAndSettle();
    expect(repository().changes, isEmpty);

    await tester.tap(segment(en.appearanceThemeDark));
    await tester.pumpAndSettle();
    expect(repository().changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.dark),
    ]);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('while it is saved, the pick shows with a named spinner and '
      'nothing else can be picked', (tester) async {
    final semantics = tester.ensureSemantics();
    final saved = Completer<void>();
    repository().beforeCall = (call) async {
      if (call.startsWith('update')) await saved.future;
    };
    await pumpAccountTab(tester);

    await tester.tap(find.text(en.appearanceThemeLight));
    await tester.pump();

    expect(
      tester.getSemantics(find.text(en.appearanceThemeLight)),
      isSemantics(isSelected: true),
    );
    expect(onSelectionChanged(tester), isNull);
    expect(find.bySemanticsLabel(en.accountSettingsSaving), findsOneWidget);

    saved.complete();
    await tester.pumpAndSettle();
    expect(onSelectionChanged(tester), isNotNull);
    expect(find.bySemanticsLabel(en.accountSettingsSaving), findsNothing);
    semantics.dispose();
  });

  testWidgets('a save outlives scrolling the row out of view, and its '
      'refusal shows when it comes back', (tester) async {
    final saved = Completer<void>();
    repository()
      ..beforeCall = (call) async {
        if (call.startsWith('update')) await saved.future;
      }
      ..failures['update'] = const ValidationFailed(code: 2002);
    await pumpAccountTab(tester);
    // The spinner of the save runs on: no settling until it is done.
    Future<void> scrollToTop() async {
      await tester.drag(tabList(), const Offset(0, 5000));
      await tester.pump(const Duration(seconds: 2));
    }

    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pump();
    await scrollToTop();
    expect(find.text(en.appearanceTheme, skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(en.appearanceHeading),
      100,
      scrollable: tabList(),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(onSelectionChanged(tester), isNull);
    expect(tester.widget<SegmentedButton<ColorSchema>>(segments).selected, {
      ColorSchema.dark,
    });

    await scrollToTop();
    tester.takeAnnouncements();
    saved.complete();
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.accountSettingsInvalid),
    ]);
    await scrollToAppearance(tester);
    expect(find.text(en.accountSettingsInvalid), findsOneWidget);
    expect(onSelectionChanged(tester), isNotNull);
  });

  testWidgets('a refused theme is shown at the control and announced', (
    tester,
  ) async {
    repository().failures['update'] = const ValidationFailed(code: 2002);
    await pumpAccountTab(tester);

    tester.takeAnnouncements();
    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pumpAndSettle();

    expect(find.text(en.accountSettingsInvalid), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(en.accountSettingsInvalid)).dy,
      greaterThan(tester.getBottomLeft(segments).dy),
    );
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.accountSettingsInvalid),
    ]);
    expect(find.byType(SnackBar), findsNothing);
    expect(brightness(tester), Brightness.light);
  });

  testWidgets('without a connection a snackbar says so and the stored theme '
      'stays', (tester) async {
    repository().failures['update'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpAccountTab(tester);

    await tester.tap(find.text(en.appearanceThemeDark));
    await tester.pumpAndSettle();

    expect(find.text(en.accountSettingsNeedsConnection), findsOneWidget);
    expect(tester.widget<SegmentedButton<ColorSchema>>(segments).selected, {
      ColorSchema.auto,
    });
    expect(brightness(tester), Brightness.light);
  });

  group('only shows', () {
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

      expect(segments, findsOneWidget);
      expect(onSelectionChanged(tester), isNull);
      expect(
        tester.getSemantics(find.text(en.appearanceTheme)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets('while a new sign-in is needed', (tester) async {
      await pumpAccountTab(tester, needsReauth: true);

      expect(segments, findsOneWidget);
      expect(onSelectionChanged(tester), isNull);
    });

    testWidgets('while signing out', (tester) async {
      final release = Completer<void>();
      auth.secureStore.beforeDelete = (_) => release.future;
      await pumpAccountTab(tester);
      expect(onSelectionChanged(tester), isNotNull);

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
      expect(onSelectionChanged(tester), isNull);

      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ConnectServerScreen), findsOneWidget);
    });
  });

  testWidgets('a guest follows the system: no theme, the device rows stay', (
    tester,
  ) async {
    useSystemPalette(tester);
    usePhoneSurface(tester);
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabAccount);
    await scrollToAppearance(tester);

    expect(
      find.widgetWithText(SwitchListTile, en.appearanceSystemColors),
      findsOneWidget,
    );
    expect(find.text(en.appearanceTheme), findsNothing);
    expect(segments, findsNothing);
  });

  testWidgets('a guest with neither a palette nor the language row has no '
      'Appearance section', (tester) async {
    usePhoneSurface(tester);
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabAccount);
    // The Privacy section's header at the top, the Server section below it.
    await tester.scrollUntilVisible(
      find.text(en.privacyTitle),
      100,
      scrollable: tabList(),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.accountServerHeading), findsOneWidget);
    expect(find.text(en.appearanceHeading, skipOffstage: false), findsNothing);
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
    expect(find.text(de.appearanceSavedToAccount), findsOneWidget);
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
