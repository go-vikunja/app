import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/client_cert_required_dialog.dart';

void main() {
  Future<void> pumpDialogHarness(
    WidgetTester tester,
    void Function(BuildContext) onPressed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onPressed(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the title and body copy', (tester) async {
    await pumpDialogHarness(tester, (context) {
      showDialog<String?>(
        context: context,
        builder: (context) => const ClientCertRequiredDialog(),
      );
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Client Certificate Required'), findsOneWidget);
    expect(
      find.text(
        'This server requires a client certificate to connect. '
        'Would you like to select one now?',
      ),
      findsOneWidget,
    );
    expect(find.text('Not Now'), findsOneWidget);
    expect(find.text('Select Certificate'), findsOneWidget);
  });

  testWidgets('"Not Now" resolves the dialog to null', (tester) async {
    String? result = 'unset';

    await pumpDialogHarness(tester, (context) {
      showDialog<String?>(
        context: context,
        builder: (context) => const ClientCertRequiredDialog(),
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Client Certificate Required'), findsNothing);
  });

  testWidgets('returns the alias selected by the certificate picker', (
    tester,
  ) async {
    String? result;

    await pumpDialogHarness(tester, (context) {
      showDialog<String?>(
        context: context,
        builder: (context) => ClientCertRequiredDialog(
          chooseClientCertificate: () async => 'selected-alias',
        ),
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select Certificate'));
    await tester.pumpAndSettle();

    expect(result, 'selected-alias');
  });
}
