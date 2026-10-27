import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';

import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  final origin = OriginKey.of(Uri.parse('https://vikunja.example.com'));
  final selfSigned = tlsFixtureCertificate('selfsigned.pem');
  late AuthFakes auth;
  late FakeCertificateChecks checks;
  late FakeAttachmentPicker picker;
  late Directory directory;

  setUp(() {
    auth = AuthFakes();
    checks = FakeCertificateChecks();
    picker = FakeAttachmentPicker();
    directory = Directory.systemTemp.createTempSync('picked');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> pumpCertificatePage(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      overrides: [
        checks.providerOverride,
        picker.providerOverride,
        ...overrides,
      ],
    );
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push(
            AppRoutes.connectionFor(
              origin,
              editor: ConnectionEditor.certificate,
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  /// The picker copies and reads real files.
  Future<void> tapWithFiles(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the trust sheet', () {
    testWidgets('shows the origin, the fingerprint in rows of four pairs as '
        'one label, subject, issuer, self-signed and validity', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCertificatePage(tester);

      expect(find.byType(CertificatePage), findsOneWidget);
      expect(find.text('$origin'), findsOneWidget);
      final pairs = selfSigned.sha256Pairs;
      final rows = [
        for (var i = 0; i < 32; i += 4) pairs.skip(i).take(4).join(' '),
      ].join('\n');
      expect(find.text(rows), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${en.connectionFingerprintLabel}: ${pairs.join(' ')}',
        ),
        findsOneWidget,
      );
      expect(find.text(selfSigned.subject), findsOneWidget);
      expect(
        find.text('${selfSigned.issuer} · ${en.connectionSelfSigned}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('openssl x509 -noout -fingerprint -sha256'),
        findsOneWidget,
      );
      expect(find.text(en.connectionBrowserWarnsToo), findsOneWidget);
      expect(find.text(en.connectionCertificateExpired), findsNothing);
      semantics.dispose();
    });

    testWidgets('copies the fingerprint colon-separated with the plain '
        'clipboard', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpCertificatePage(tester);

      await tapVisible(tester, find.text(en.connectionCopyFingerprint));

      expect(copied, [selfSigned.sha256Pairs.join(':')]);
    });

    testWidgets('trusting pins exactly that certificate for exactly that '
        'origin', (tester) async {
      await pumpCertificatePage(tester);

      await tapVisible(tester, find.text(en.connectionTrustCertificate));

      expect(find.byType(CertificatePage), findsNothing);
      final profiles = profilesOver(auth);
      final pinned = await profiles.metadataFor(origin);
      expect(pinned?.pin?.certificate, selfSigned);
      final otherPort = OriginKey.of(
        Uri.parse('https://vikunja.example.com:3456'),
      );
      expect(await profiles.metadataFor(otherPort), isNull);
    });

    testWidgets('warns about an expired certificate', (tester) async {
      checks.fetched = ProbedCertificate(renewedCertificate);
      await pumpCertificatePage(
        tester,
        overrides: [clockProvider.overrideWithValue(() => DateTime.utc(2028))],
      );

      expect(find.text(en.connectionCertificateExpired), findsOneWidget);
    });

    testWidgets('explains a failed fetch and fetches again', (tester) async {
      checks.fetched = const CertificateProbeFailed(
        CertificateProbeProblem.unreachable,
      );
      await pumpCertificatePage(tester);

      expect(
        find.text(en.connectionProbeUnreachable(origin.authority)),
        findsOneWidget,
      );
      expect(find.text(en.connectionTrustCertificate), findsNothing);

      checks.fetched = ProbedCertificate(selfSigned);
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(checks.fetches, hasLength(2));
      expect(find.text(en.connectionTrustCertificate), findsOneWidget);
    });

    testWidgets('a long-lived certificate the device does not trust: the '
        'browser note, Trust first and filled, the CA option outlined', (
      tester,
    ) async {
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionBrowserWarnsToo), findsOneWidget);
      expect(find.text(en.connectionTrustDeviceTrusted), findsNothing);
      expect(find.text(en.connectionTrustShortLived), findsNothing);
      final trust = find.text(en.connectionTrustCertificate);
      final ca = find.text(en.connectionUseCa);
      expect(
        find.ancestor(of: trust, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: ca, matching: find.byType(OutlinedButton)),
        findsOneWidget,
      );
      expect(tester.getTopLeft(trust).dy, lessThan(tester.getTopLeft(ca).dy));
    });

    testWidgets('a certificate the device already trusts: says so, no '
        'browser note, nothing invites trusting it', (tester) async {
      checks.fetched = ProbedCertificate(selfSigned, deviceTrusted: true);
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionTrustDeviceTrusted), findsOneWidget);
      expect(find.text(en.connectionBrowserWarnsToo), findsNothing);
      final trust = find.text(en.connectionTrustCertificate);
      expect(trust, findsOneWidget);
      expect(
        find.ancestor(of: trust, matching: find.byType(FilledButton)),
        findsNothing,
      );
      expect(
        find.ancestor(of: trust, matching: find.byType(OutlinedButton)),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a short-lived certificate: warns that a pin breaks at each '
        'renewal and makes the CA option the primary one', (tester) async {
      final shortLived = CertificateInfo(
        sha256: 'EF' * 32,
        subject: '/CN=vikunja.example.com',
        issuer: '/CN=Caddy Local Authority - ECC Intermediate',
        notBefore: DateTime.utc(2026, 10, 27),
        notAfter: DateTime.utc(2026, 10, 27, 12),
      );
      checks.fetched = ProbedCertificate(shortLived);
      await pumpCertificatePage(
        tester,
        overrides: [
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 27, 6)),
        ],
      );

      expect(find.text(en.connectionTrustShortLived), findsOneWidget);
      final trust = find.text(en.connectionTrustCertificate);
      final ca = find.text(en.connectionUseCa);
      expect(
        find.ancestor(of: ca, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: trust, matching: find.byType(OutlinedButton)),
        findsOneWidget,
      );
      expect(tester.getTopLeft(ca).dy, lessThan(tester.getTopLeft(trust).dy));
    });

    testWidgets('says that a pin replaces the trusted CA', (tester) async {
      await profilesOver(auth).trustCaCertificate(
        origin,
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionPinReplacesCa), findsOneWidget);
    });
  });

  group('a CA certificate instead', () {
    testWidgets('is checked against the server and stored when it vouches '
        'for it; the picked copy is gone', (tester) async {
      final copy = pickedCopyOf('ca.pem', directory: directory);
      picker.files = [copy];
      await pumpCertificatePage(tester);

      await tapWithFiles(tester, find.text(en.connectionUseCa));

      expect(picker.calls, ['files single']);
      expect(picker.maxBytes, [64 * 1024]);
      expect(checks.checkedPems, [tlsFixtureText('ca.pem')]);
      expect(File(copy.path).existsSync(), isFalse);
      expect(find.byType(CertificatePage), findsNothing);
      final profile = await profilesOver(auth).metadataFor(origin);
      expect(profile?.caCertificate?.fileName, 'ca.pem');
      expect(profile?.pin, isNull);
    });

    testWidgets('that did not issue the server certificate offers to trust '
        'the certificate the server presented', (tester) async {
      picker.files = [pickedCopyOf('client-ca.pem', directory: directory)];
      checks.caCheck = CaNotTrusted(thirdCertificate);
      await pumpCertificatePage(tester);

      await tapWithFiles(tester, find.text(en.connectionUseCa));

      expect(find.text(en.connectionCaNotTrusted), findsOneWidget);
      expect(find.text(en.connectionCaNotTrustedLeaf), findsOneWidget);
      await tapVisible(tester, find.text(en.connectionTrustCertificate).last);

      final profile = await profilesOver(auth).metadataFor(origin);
      expect(profile?.pin?.sha256, thirdCertificate.sha256);
      expect(profile?.caCertificate, isNull);
    });

    testWidgets('that could not be checked can be saved anyway', (
      tester,
    ) async {
      picker.files = [pickedCopyOf('ca.pem', directory: directory)];
      checks.caCheck = const CaCheckFailed(CertificateProbeProblem.timeout);
      await pumpCertificatePage(tester);

      await tapWithFiles(tester, find.text(en.connectionUseCa));

      expect(
        find.text(en.connectionCaCheckFailed(origin.authority)),
        findsOneWidget,
      );
      await tapVisible(tester, find.text(en.connectionCaSaveAnyway));

      final profile = await profilesOver(auth).metadataFor(origin);
      expect(profile?.caCertificate?.fileName, 'ca.pem');
    });

    testWidgets('that is no certificate file is refused; the copy is gone '
        'too', (tester) async {
      final copy = pickedCopyOf('client.key', directory: directory);
      picker.files = [copy];
      checks.caCheck = const CaFileInvalid();
      await pumpCertificatePage(tester);

      await tapWithFiles(tester, find.text(en.connectionUseCa));

      expect(find.text(en.connectionCaFileInvalid), findsOneWidget);
      expect(File(copy.path).existsSync(), isFalse);
      expect(await profilesOver(auth).metadataFor(origin), isNull);
    });

    testWidgets('a cancelled pick changes nothing', (tester) async {
      await pumpCertificatePage(tester);

      await tapVisible(tester, find.text(en.connectionUseCa));

      expect(checks.checkedPems, isEmpty);
      expect(find.byType(CertificatePage), findsOneWidget);
    });
  });

  group('the review of a changed certificate', () {
    Future<void> pinAndRecord(CertificateInfo? seen) async {
      final profiles = profilesOver(auth);
      await profiles.trustCertificate(origin, selfSigned);
      if (seen != null) await profiles.recordPinMismatch(origin, seen);
    }

    testWidgets('with the certificate seen then offers to accept it first', (
      tester,
    ) async {
      await pinAndRecord(renewedCertificate);
      checks.fetched = ProbedCertificate(renewedCertificate);
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionReviewTitle), findsOneWidget);
      expect(find.text(en.connectionPinnedTitle), findsOneWidget);
      expect(find.text(en.connectionReviewProbed), findsOneWidget);
      expect(find.text(en.connectionReviewSame), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, en.connectionReviewAccept),
        findsOneWidget,
      );

      await tapVisible(tester, find.text(en.connectionReviewAccept));

      final profile = await profilesOver(auth).metadataFor(origin);
      expect(profile?.pin?.sha256, renewedCertificate.sha256);
      expect(profile?.lastPinMismatch, isNull);
    });

    testWidgets('with yet another certificate says so and preselects '
        'nothing; keeping dismisses the notice', (tester) async {
      await pinAndRecord(renewedCertificate);
      checks.fetched = ProbedCertificate(thirdCertificate);
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionReviewDiffers), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, en.connectionReviewAccept),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, en.connectionReviewKeep),
        findsNothing,
      );
      final keep = tester.getTopLeft(find.text(en.connectionReviewKeep)).dy;
      final accept = tester.getTopLeft(find.text(en.connectionReviewAccept)).dy;
      expect(keep, lessThan(accept));

      await tapVisible(tester, find.text(en.connectionReviewKeep));

      final profile = await profilesOver(auth).metadataFor(origin);
      expect(profile?.pin?.sha256, selfSigned.sha256);
      expect(profile?.lastPinMismatch, isNull);
    });

    testWidgets('with the trusted certificate back offers only to keep it', (
      tester,
    ) async {
      await pinAndRecord(renewedCertificate);
      await pumpCertificatePage(tester);

      expect(find.text(en.connectionReviewMatchesTrusted), findsOneWidget);
      expect(find.text(en.connectionReviewAccept), findsNothing);
      expect(
        find.widgetWithText(FilledButton, en.connectionReviewKeep),
        findsOneWidget,
      );
    });
  });
}
