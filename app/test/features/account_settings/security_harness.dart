import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

/// A 2.7.0 server at `https://tasks.example.org/vikunja` (http with
/// [insecure]) that reports no frontend address, with password sign-in and
/// the given features.
ServerConnection securityServer({
  bool totp = true,
  bool caldav = true,
  bool userDeletion = true,
  bool insecure = false,
  String version = 'v2.7.0',
}) {
  final info = ServerInfo(
    version: ServerVersion.tryParse(version),
    rawVersion: version,
    totpEnabled: totp,
    caldavEnabled: caldav,
    userDeletionEnabled: userDeletion,
    auth: const AuthMethods(localEnabled: true),
  );
  const versions = {ApiVersion.v1, ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse(
      '${insecure ? 'http' : 'https'}://tasks.example.org/vikunja',
    ),
    apiVersions: versions,
    info: info,
    capabilities: ServerCapabilities.derive(info: info, apiVersions: versions),
  );
}

Uri webPage(String path) =>
    Uri.parse('https://tasks.example.org/vikunja/$path');

/// The fakes behind one account's settings pages, and the app pumped on
/// one of them.
final class SecurityHarness {
  final DateTime now = DateTime.now();
  final auth = AuthFakes();
  late SyncFakes data = SyncFakes(now: now);
  FakeExternalLinkOpener links = FakeExternalLinkOpener();

  /// What the pages take for now; null is the real clock.
  DateTime? clock;

  FakeAccountSecurityRepository get security => data.accountSecurity;
  FakeSensitiveClipboard get clipboard => data.clipboard;
  FakeSecureDisplay get secureDisplay => data.secureDisplay;

  /// Signed in on [connection] (a [securityServer] by default) with
  /// [state] as the account settings, then [location] pushed over the
  /// shell, unless null.
  Future<void> pump(
    WidgetTester tester, {
    String? location = AppRoutes.accountSettings,
    AccountSettingsState? state,
    ServerConnection? connection,
    bool needsReauth = false,
    Size size = phoneSize,
    List<ProviderObserver> observers = const [],
  }) async {
    usePhoneSurface(tester, logicalSize: size);
    if (state != null) data.shared.accountSettings.state = state;
    await auth.seedAccount(
      connection ?? securityServer(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: needsReauth,
    );
    await tester.pumpWidget(
      ProviderScope(
        observers: observers,
        overrides: [
          ...appOverrides(auth: auth, sync: data, linkOpener: links),
          clockProvider.overrideWithValue(() => clock ?? DateTime.now()),
        ],
        child: const VikunjaApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) {
      unawaited(containerOf(tester).read(appRouterProvider).push(location));
      await tester.pumpAndSettle();
    }
  }
}

void resumeApp(WidgetTester tester) => [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
].forEach(tester.binding.handleAppLifecycleStateChanged);

/// From the top of the first scrollable inside [page] down to [finder].
Future<void> scrollToIn(WidgetTester tester, Type page, Finder finder) async {
  final list = find
      .descendant(of: find.byType(page), matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pump();
  for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -150));
    await tester.pump();
  }
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.4);
  await tester.pumpAndSettle();
}
