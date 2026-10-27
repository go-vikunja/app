import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/secret_text_field.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final secure = OriginKey.of(Uri.parse('https://vikunja.example.com'));
  final plain = OriginKey.of(Uri.parse('http://192.168.1.20:3456'));
  const id = 'dummy-client-id.access';
  const secret = 'dummy-client-secret-0123456789';
  late AuthFakes auth;
  late SyncFakes sync;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes();
  });

  /// [seed] runs once the app started, which wipes the secure storage of a
  /// fresh install.
  Future<void> pumpHeaders(
    WidgetTester tester,
    OriginKey origin, {
    Future<void> Function()? seed,
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1800));
    await pumpVikunjaApp(tester, auth: auth, sync: sync);
    await seed?.call();
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push(
            AppRoutes.connectionFor(origin, editor: ConnectionEditor.headers),
          ),
    );
    await tester.pumpAndSettle();
  }

  Finder valueField(int index) => find
      .descendant(
        of: find.byType(SecretTextField).at(index),
        matching: find.byType(TextField),
      )
      .first;

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(en.connectionSave));
    await tester.tap(find.text(en.connectionSave));
    await tester.pumpAndSettle();
  }

  testWidgets('the Cloudflare preset asks for the two values, masked and '
      'without suggestions or autofill', (tester) async {
    await pumpHeaders(tester, secure);

    expect(find.byType(HeadersPage), findsOneWidget);
    expect(find.text('CF-Access-Client-Id'), findsWidgets);
    expect(find.text('CF-Access-Client-Secret'), findsWidgets);
    expect(find.byType(SecretTextField), findsNWidgets(2));
    final field = tester.widget<TextField>(valueField(0));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
    // An empty list would still turn autofill on.
    expect(field.autofillHints, isNull);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(find.text(en.connectionServiceTokenHint), findsOneWidget);
  });

  testWidgets('a revealed value keeps the window out of screenshots until it '
      'is hidden or the page closes', (tester) async {
    await pumpHeaders(tester, secure);
    sync.secureWindow.changes.clear();

    await tester.tap(find.byTooltip(en.connectionShowValue).first);
    await tester.pump();
    expect(sync.secureWindow.secure, isTrue);
    expect(tester.widget<TextField>(valueField(0)).obscureText, isFalse);

    await tester.tap(find.byTooltip(en.connectionHideValue));
    await tester.pump();
    expect(sync.secureWindow.secure, isFalse);

    await tester.tap(find.byTooltip(en.connectionShowValue).first);
    await tester.tap(find.byTooltip(en.connectionShowValue).last);
    await tester.pump();
    expect(sync.secureWindow.secure, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HeadersPage), findsNothing);
    expect(sync.secureWindow.secure, isFalse);
    expect(sync.secureWindow.changes, [true, false, true, false]);
  });

  testWidgets('stores the trimmed values for exactly that origin and '
      'returns', (tester) async {
    await pumpHeaders(tester, secure);

    await tester.enterText(valueField(0), id);
    await tester.enterText(valueField(1), '  $secret ');
    await save(tester);

    expect(find.byType(HeadersPage), findsNothing);
    final profile = await profilesOver(auth).forOrigin(secure);
    expect(profile?.headers, {
      'CF-Access-Client-Id': id,
      'CF-Access-Client-Secret': secret,
    });
  });

  testWidgets('refuses an empty value, a no-break space and a name the app '
      'sets itself, storing nothing', (tester) async {
    await pumpHeaders(tester, secure);

    await save(tester);
    expect(find.text(en.connectionHeaderValueEmpty), findsNWidgets(2));

    await tester.tap(find.text(en.connectionHeaderPresetCustom));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.connectionHeaderName).first,
      'Authorization',
    );
    await tester.enterText(valueField(0), 'dummy value');
    await save(tester);

    expect(find.text(en.connectionHeaderNameReserved), findsOneWidget);
    expect(find.text(en.connectionHeaderValueNonAscii), findsOneWidget);
    expect(find.byType(HeadersPage), findsOneWidget);
    expect(await profilesOver(auth).metadataFor(secure), isNull);
  });

  testWidgets('stored headers come back for editing', (tester) async {
    await pumpHeaders(
      tester,
      secure,
      seed: () =>
          profilesOver(auth).setHeaders(secure, {'X-Gate-Token': 'dummy'}),
    );

    expect(find.text('X-Gate-Token'), findsOneWidget);
    expect(find.byType(SecretTextField), findsOneWidget);
    expect(tester.widget<TextField>(valueField(0)).controller!.text, 'dummy');
  });

  testWidgets('names whose values went missing come back empty, to enter '
      'again', (tester) async {
    // The fresh install's wipe takes the values and leaves the names.
    await profilesOver(auth).setHeaders(secure, {'X-Gate-Token': 'dummy'});
    await pumpHeaders(tester, secure);

    expect(find.text('X-Gate-Token'), findsOneWidget);
    expect(tester.widget<TextField>(valueField(0)).controller!.text, isEmpty);
    await tester.enterText(valueField(0), 'dummy-again');
    await save(tester);

    final profile = await profilesOver(auth).forOrigin(secure);
    expect(profile?.headers, {'X-Gate-Token': 'dummy-again'});
  });

  testWidgets('for an http address without the permission, asks for it '
      'first and records it before the headers', (tester) async {
    await pumpHeaders(tester, plain);

    expect(find.text(en.connectionHeadersUnencrypted), findsOneWidget);
    await tester.enterText(valueField(0), id);
    await tester.enterText(valueField(1), secret);
    await save(tester);

    expect(find.text(en.insecureDialogTitle), findsOneWidget);
    await tester.tap(find.text(en.insecureDialogContinue));
    await tester.pumpAndSettle();

    expect(find.byType(HeadersPage), findsNothing);
    final profile = await profilesOver(auth).forOrigin(plain);
    expect(profile?.hasCleartextConsent, isTrue);
    expect(profile?.headerNames, [
      'CF-Access-Client-Id',
      'CF-Access-Client-Secret',
    ]);
  });

  testWidgets('declining the permission stores nothing', (tester) async {
    await pumpHeaders(tester, plain);

    await tester.enterText(valueField(0), id);
    await tester.enterText(valueField(1), secret);
    await save(tester);
    await tester.tap(find.text(en.insecureDialogCancel));
    await tester.pumpAndSettle();

    expect(find.byType(HeadersPage), findsOneWidget);
    expect(await profilesOver(auth).metadataFor(plain), isNull);
  });
}
