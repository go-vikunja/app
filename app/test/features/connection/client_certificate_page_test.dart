import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/client_certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';

import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  final origin = OriginKey.of(Uri.parse('https://vikunja.example.com'));
  late AuthFakes auth;
  late SyncFakes sync;
  late FakeAttachmentPicker picker;
  late Directory directory;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes();
    picker = FakeAttachmentPicker();
    directory = Directory.systemTemp.createTempSync('picked');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> pumpImport(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1400));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: sync,
      overrides: [picker.providerOverride],
    );
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push(
            AppRoutes.connectionFor(
              origin,
              editor: ConnectionEditor.clientCertificate,
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(en.connectionChooseFile));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(en.connectionSave));
    await tester.tap(find.text(en.connectionSave));
    await tester.pumpAndSettle();
  }

  Finder passwordField() => find.byType(TextField);

  testWidgets('imports the file with its password for that origin; the '
      'picked copy is gone at once', (tester) async {
    final copy = pickedCopyOf('client.p12', directory: directory);
    picker.files = [copy];
    await pumpImport(tester);

    expect(find.byType(ClientCertificatePage), findsOneWidget);
    await choose(tester);
    expect(find.text('client.p12'), findsOneWidget);
    expect(File(copy.path).existsSync(), isFalse);
    expect(tester.widget<TextField>(passwordField()).obscureText, isTrue);

    await tester.enterText(passwordField(), tlsFixturePassword);
    await save(tester);

    expect(find.byType(ClientCertificatePage), findsNothing);
    final profile = await profilesOver(auth).forOrigin(origin);
    expect(profile?.clientCertificate?.fileName, 'client.p12');
    expect(profile?.secrets.pkcs12, tlsFixture('client.p12'));
    expect(profile?.secrets.pkcs12Password, tlsFixturePassword);
  });

  testWidgets('a wrong password says so and stores nothing', (tester) async {
    picker.files = [pickedCopyOf('client.p12', directory: directory)];
    await pumpImport(tester);
    await choose(tester);

    await tester.enterText(passwordField(), 'not-the-dummy-password');
    await save(tester);

    expect(find.text(en.connectionWrongPasswordOrUnsupported), findsOneWidget);
    expect(find.byType(ClientCertificatePage), findsOneWidget);
    expect(await profilesOver(auth).metadataFor(origin), isNull);
  });

  testWidgets('a file that is no certificate is refused like a wrong '
      'password', (tester) async {
    picker.files = [pickedCopyOf('ca.pem', directory: directory)];
    await pumpImport(tester);
    await choose(tester);

    await tester.enterText(passwordField(), tlsFixturePassword);
    await save(tester);

    expect(find.text(en.connectionWrongPasswordOrUnsupported), findsOneWidget);
    expect(await profilesOver(auth).metadataFor(origin), isNull);
  });

  testWidgets('asks for a file first, and refuses one above 64 KB', (
    tester,
  ) async {
    await pumpImport(tester);

    await save(tester);
    expect(find.text(en.connectionNoFileChosen), findsOneWidget);

    picker.tooLargeFiles = ['huge.p12'];
    await choose(tester);
    expect(find.text(en.connectionFileTooLarge), findsOneWidget);
    expect(picker.maxBytes.last, 64 * 1024);
  });

  testWidgets('a revealed password keeps the window out of screenshots '
      'until the page closes', (tester) async {
    await pumpImport(tester);
    sync.secureWindow.changes.clear();

    await tester.tap(find.byTooltip(en.connectionShowPassword));
    await tester.pump();
    expect(sync.secureWindow.secure, isTrue);
    expect(tester.widget<TextField>(passwordField()).obscureText, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(sync.secureWindow.secure, isFalse);
  });

  testWidgets('says the certificate is presented only to this origin', (
    tester,
  ) async {
    await pumpImport(tester);

    expect(
      find.text(en.connectionClientCertificateIntroFor('$origin')),
      findsOneWidget,
    );
  });

  testWidgets('the password field takes no part in autofill or keyboard '
      'learning', (tester) async {
    await pumpImport(tester);

    final field = tester.state(passwordField()) as AutofillClient;
    expect(field.textInputConfiguration.autofillConfiguration.enabled, isFalse);
    expect(field.textInputConfiguration.enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('explains that a private CA must be trusted in the app too, '
      'until a certificate is trusted', (tester) async {
    await pumpImport(tester);
    expect(
      find.text(en.connectionClientCertificatePrivateCaHint),
      findsOneWidget,
    );
  });
}
