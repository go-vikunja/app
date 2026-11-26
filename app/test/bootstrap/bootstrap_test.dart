import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/bootstrap.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/crash_report_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/previous_app_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("crash reports start only after the previous app's data was read, "
      'as their registry read wipes it', () async {
    final steps = <String>[];
    final auth = AuthFakes();
    auth.secureStore
      ..values.addAll(previousAppValues(refreshToken: null))
      ..beforeRead = (key) async => steps.add('read $key');
    final container = createAppContainer(
      overrides: [
        ...appOverrides(auth: auth),
        previousAppPlatformProvider.overrideWithValue(
          FakePreviousAppPlatform(log: steps),
        ),
        crashReportSdkProvider.overrideWithValue(FakeCrashReportSdk()),
        crashReportsDsnProvider.overrideWith((ref) {
          steps.add('crash reporter');
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);

    await prepareFirstFrame(container);

    expect(
      steps,
      containsAllInOrder(['read server-address', 'clear', 'crash reporter']),
    );
    expect(container.read(previousAppProvider).value?.note, isNotNull);
    expect(auth.secureStore.values, isEmpty);
  });

  test("a later start loads the previous app's record before the first "
      'frame, so Connect can fill in its server', () async {
    final auth = AuthFakes();
    auth.preferences.values[installMarkerKey] = '1';
    final server = Uri.parse('https://old.example');
    await PreviousAppRecord(server: server).write(auth.preferences);
    final container = createAppContainer(
      overrides: [
        ...appOverrides(auth: auth),
        previousAppPlatformProvider.overrideWithValue(
          FakePreviousAppPlatform(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await prepareFirstFrame(container);

    expect(container.read(previousAppProvider).value?.record?.server, server);
  });

  testWidgets('a start whose account list cannot be read still reaches a '
      'screen: Connect, with the stored accounts left as they were', (
    tester,
  ) async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    auth.preferences.values[installMarkerKey] = '1';
    final stored = auth.preferences.values[AccountRegistry.storageKey];
    // Every read fails: Riverpod retries a failed build, so a registry that
    // fails only once is read again and signs in.
    auth.preferences.failReads.add(AccountRegistry.storageKey);
    final container = createAppContainer(
      overrides: [
        ...appOverrides(auth: auth),
        previousAppPlatformProvider.overrideWithValue(
          FakePreviousAppPlatform(),
        ),
        ...crashReportOverrides(dsn: null),
      ],
    );

    var prepared = false;
    unawaited(prepareFirstFrame(container).then((_) => prepared = true));
    for (var waited = 0; !prepared && waited < 60; waited++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(prepared, isTrue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VikunjaApp(),
      ),
    );
    final connect = find.byType(ConnectServerScreen);
    // Releasing the first frame does not stop the registry's retries.
    for (var waited = 0; connect.evaluate().isEmpty && waited < 60; waited++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    expect(connect, findsOneWidget);
    expect(
      container.read(appRouterProvider).state.matchedLocation,
      AppRoutes.connect,
    );
    expect(auth.preferences.values[AccountRegistry.storageKey], stored);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('a stalled account read does not hold the first frame', (
    tester,
  ) async {
    final release = Completer<void>();
    final auth = AuthFakes();
    auth.preferences.values[installMarkerKey] = '1';
    auth.preferences.beforeRead = (key) async {
      if (key == AccountRegistry.storageKey) await release.future;
    };
    final container = createAppContainer(
      overrides: [
        ...appOverrides(auth: auth),
        previousAppPlatformProvider.overrideWithValue(
          FakePreviousAppPlatform(),
        ),
        ...crashReportOverrides(dsn: null),
      ],
    );
    var prepared = false;
    unawaited(prepareFirstFrame(container).then((_) => prepared = true));
    await tester.pump();
    expect(prepared, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(prepared, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VikunjaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(en.startupAccountsSlow), findsOneWidget);
    expect(find.byType(ConnectServerScreen), findsNothing);

    release.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('retry can recover after an account storage read never answers', (
    tester,
  ) async {
    final auth = AuthFakes();
    final stale = Completer<void>();
    auth.preferences.values[installMarkerKey] = '1';
    var reads = 0;
    auth.preferences.beforeRead = (key) async {
      if (key == AccountRegistry.storageKey && reads++ == 0) {
        await stale.future;
      }
    };
    final container = createAppContainer(
      overrides: [
        ...appOverrides(auth: auth),
        ...crashReportOverrides(dsn: null),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VikunjaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(en.startupAccountsSlow), findsOneWidget);

    await tester.tap(find.text(en.retry));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

    expect(reads, greaterThan(1));
    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(stale.isCompleted, isFalse);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('legacy sign-in still runs when the first-frame wait expires', (
    tester,
  ) async {
    final auth = AuthFakes();
    final platform = FakePreviousAppPlatform();
    final release = Completer<void>();
    auth.secureStore.values.addAll(previousAppValues());
    auth.preferences.beforeRead = (key) async {
      if (key == AccountRegistry.storageKey && platform.log.contains('clear')) {
        await release.future;
      }
    };
    auth.tokenGateway.onRefresh = (_) async =>
        issueTokens(issuedAt: DateTime.now().toUtc());
    auth.accountGateway.onCurrentUser = (_) async =>
        const User(id: 7, username: 'alice');
    final container = createAppContainer(
      overrides: [
        ...appOverrides(
          auth: auth,
          connector: FakeServerConnector.succeeding(
            fullServer270(root: 'https://vikunja.example.com'),
          ),
        ),
        previousAppPlatformProvider.overrideWithValue(platform),
        ...crashReportOverrides(dsn: null),
      ],
    );
    var prepared = false;
    unawaited(prepareFirstFrame(container).then((_) => prepared = true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(prepared, isTrue);
    expect(auth.tokenGateway.refreshedTokens, isEmpty);

    release.complete();
    await tester.pump();
    expect(auth.tokenGateway.refreshedTokens, ['previous-refresh-token']);
    expect(
      container.read(previousAppProvider).value?.session,
      isA<PreviousAppSessionKept>(),
    );
    container.dispose();
  });
}
