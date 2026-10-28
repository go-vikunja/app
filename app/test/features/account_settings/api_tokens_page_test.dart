import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_token_form_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/route_report.dart';
import 'security_harness.dart';

/// Every value a provider takes, as text.
final class _ProviderValues extends ProviderObserver {
  final values = <String>[];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) =>
      values.add('$value');

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) => values.add('$newValue');
}

/// What the app has the screen reader say from now on.
List<String> recordAnnouncements(WidgetTester tester) {
  final messages = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message case {
        'type': 'announce',
        'data': {'message': final String text},
      }) {
        messages.add(text);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return messages;
}

void main() {
  late SecurityHarness harness;

  setUp(() => harness = SecurityHarness());

  Finder dialogText(String label) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(label));

  group('the list', () {
    testWidgets('shows each token with its expiry and permissions', (
      tester,
    ) async {
      // A fixed clock and calendar dates: the page counts calendar days, and
      // 72 hours before a moment near midnight can land two dates back
      // across a daylight-saving change.
      final clock = DateTime(2026, 10, 27, 12);
      harness.clock = clock;
      harness.security.apiTokenList = [
        fakeApiToken(expiresAt: DateTime(2026, 11, 16, 12)),
        fakeApiToken(
          id: 2,
          title: 'Old script',
          expiresAt: DateTime(clock.year, clock.month, clock.day - 3, 12),
          permissions: const {
            'tasks': ['read_all'],
            'projects': ['read_all', 'read_one'],
          },
        ),
      ];
      await harness.pump(tester, location: AppRoutes.accountApiTokens);

      expect(find.text('Home Assistant'), findsOneWidget);
      expect(find.textContaining('Expires'), findsOneWidget);
      expect(find.text(en.apiTokensPermissionCount(2)), findsOneWidget);
      final expired = find.text(en.apiTokensExpired(en.relativeDaysAgo(3)));
      expect(expired, findsOneWidget);
      expect(
        tester.widget<Text>(expired).style?.color,
        Theme.of(tester.element(expired)).colorScheme.error,
      );
      expect(find.text(en.apiTokensPermissionCount(3)), findsOneWidget);
    });

    testWidgets('empty, it offers a new token', (tester) async {
      await harness.pump(tester, location: AppRoutes.accountApiTokens);

      expect(find.text(en.apiTokensEmptyTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, en.apiTokensNew));
      await tester.pumpAndSettle();

      expect(find.byType(ApiTokenFormPage), findsOneWidget);
    });

    testWidgets("links to the server's API documentation", (tester) async {
      await harness.pump(tester, location: AppRoutes.accountApiTokens);

      await tester.tap(find.text(en.apiTokensDocs));
      await tester.pumpAndSettle();

      expect(harness.links.opened, [webPage('api/v1/docs')]);
    });

    testWidgets('a token opens its details and is deleted after asking', (
      tester,
    ) async {
      harness.security.apiTokenList = [
        fakeApiToken(expiresAt: harness.now.add(const Duration(days: 20))),
      ];
      await harness.pump(tester, location: AppRoutes.accountApiTokens);

      await tester.tap(find.text('Home Assistant'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks: Read all, Update'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, en.apiTokensDelete));
      await tester.pumpAndSettle();
      expect(find.text(en.apiTokensDeleteTitle('Home Assistant')), findsOne);
      expect(find.text(en.apiTokensDeleteBody), findsOneWidget);
      await tester.tap(dialogText(en.apiTokensDelete));
      await tester.pumpAndSettle();

      expect(harness.security.calls, contains('deleteApiToken 1'));
      expect(find.text('Home Assistant'), findsNothing);
    });

    testWidgets(
      'a token deleted elsewhere says so and the list is read again',
      (tester) async {
        harness.security.apiTokenList = [
          fakeApiToken(expiresAt: harness.now.add(const Duration(days: 20))),
        ];
        harness.security.failures['deleteApiToken'] = const Forbidden(
          message: 'Forbidden',
        );
        await harness.pump(tester, location: AppRoutes.accountApiTokens);

        await tester.tap(find.text('Home Assistant'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(OutlinedButton, en.apiTokensDelete),
        );
        await tester.pumpAndSettle();
        await tester.tap(dialogText(en.apiTokensDelete));
        await tester.pumpAndSettle();

        expect(
          find.text(en.accountSecurityRefused('Forbidden')),
          findsOneWidget,
        );
        expect(
          harness.security.calls.where((call) => call == 'apiTokens'),
          hasLength(2),
        );
      },
    );

    testWidgets('a list that cannot be read offers a retry', (tester) async {
      harness.security.failures['apiTokens'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.pump(tester, location: AppRoutes.accountApiTokens);
      expect(find.text(en.dataFailureLoadTitle), findsOneWidget);

      harness.security.failures.clear();
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.text(en.apiTokensEmptyTitle), findsOneWidget);
    });
  });

  group('the form', () {
    Future<void> pumpForm(
      WidgetTester tester, {
      List<ProviderObserver> observers = const [],
    }) async {
      await harness.pump(
        tester,
        location: AppRoutes.accountApiTokens,
        observers: observers,
      );
      await tester.tap(find.byTooltip(en.apiTokensNew));
      await tester.pumpAndSettle();
    }

    TextButton createButton(WidgetTester tester) => tester.widget<TextButton>(
      find.widgetWithText(TextButton, en.apiTokenFormCreate),
    );

    Finder groupBox(String group) =>
        find.widgetWithText(CheckboxListTile, group);

    Future<void> scrollToText(WidgetTester tester, Finder finder) =>
        scrollToIn(tester, ApiTokenFormPage, finder);

    testWidgets('create waits for a title and a permission', (tester) async {
      await pumpForm(tester);
      expect(createButton(tester).onPressed, isNull);
      expect(find.text(en.apiTokenFormPermissionsRequired), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Script  ');
      await tester.pump();
      expect(createButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(find.text(en.apiTokenFormNameRequired), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();
      expect(find.text(en.apiTokenFormPermissionsRequired), findsNothing);
      expect(createButton(tester).onPressed, isNotNull);
    });

    testWidgets('a preset replaces the selection', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text(en.apiTokenPresetFullAccess));
      await tester.pump();
      await scrollToText(tester, groupBox('Tasks'));
      expect(find.text(en.apiTokenFormGroupSelected(5, 5)), findsNWidgets(3));

      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();
      expect(find.text(en.apiTokenFormGroupSelected(2, 5)), findsNWidgets(3));
      expect(find.text(en.apiTokenFormGroupSelected(0, 1)), findsOneWidget);
    });

    testWidgets("a group's checkbox picks and clears it, and is mixed while "
        'only some are picked', (tester) async {
      await pumpForm(tester);
      await scrollToText(tester, groupBox('Tasks'));

      CheckboxListTile tasks() =>
          tester.widget<CheckboxListTile>(groupBox('Tasks'));
      expect(tasks().value, isFalse);
      await tester.tap(groupBox('Tasks'));
      await tester.pump();
      expect(tasks().value, isTrue);
      await tester.tap(groupBox('Tasks'));
      await tester.pump();
      expect(tasks().value, isFalse);

      await tester.tap(find.byTooltip(en.apiTokenFormShowGroup('Tasks')));
      await tester.pumpAndSettle();
      await scrollToText(tester, groupBox('Read all'));
      await tester.tap(groupBox('Read all'));
      await tester.pump();
      await scrollToText(tester, groupBox('Tasks'));
      expect(tasks().value, isNull);
      expect(find.text(en.apiTokenFormGroupSelected(1, 5)), findsOneWidget);

      await tester.tap(groupBox('Tasks'));
      await tester.pump();
      expect(tasks().value, isTrue);
    });

    testWidgets('`other` comes last, as on the web', (tester) async {
      await pumpForm(tester);

      await scrollToText(tester, groupBox('Other'));
      final other = tester.getTopLeft(groupBox('Other')).dy;
      final tasks = tester.getTopLeft(groupBox('Tasks')).dy;
      expect(other, greaterThan(tasks));
    });

    testWidgets('a picked day that has passed is refused', (tester) async {
      harness.clock = DateTime(2026, 10, 21, 23, 50);
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();

      await tester.tap(find.text(en.apiTokenFormExpiry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apiTokenFormExpiryCustom));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Through'), findsOneWidget);
      expect(createButton(tester).onPressed, isNotNull);

      harness.clock = DateTime(2026, 11, 21, 0, 10);
      await tester.enterText(find.byType(TextField), 'Script 2');
      await tester.pump();

      expect(find.text(en.apiTokenFormExpiryPast), findsOneWidget);
      expect(createButton(tester).onPressed, isNull);
    });

    testWidgets('a picked day is sent as the end of that day here, in UTC', (
      tester,
    ) async {
      final clock = DateTime(2026, 3, 2, 9, 30);
      harness
        ..clock = clock
        ..security.now = () => clock;
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();

      await tester.tap(find.text(en.apiTokenFormExpiry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apiTokenFormExpiryCustom));
      await tester.pumpAndSettle();
      // The 30-day preset's April 1 is where the picker opens.
      await tester.tap(find.text('29'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apiTokenFormCreate));
      await tester.pumpAndSettle();

      final expiresAt = harness.security.createdApiTokens.single.expiresAt;
      expect(expiresAt.isUtc, isTrue);
      expect(expiresAt, DateTime(2026, 4, 29, 23, 59, 59).toUtc());
    });

    testWidgets('create shows the token once, protected, copied to the '
        'sensitive clipboard; back on the list it is there', (tester) async {
      final values = _ProviderValues();
      final logs = <String>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(
        (record) => logs.add('${record.message} ${record.error}'),
      );
      addTearDown(() {
        Logger.root.level = previousLevel;
        return subscription.cancel();
      });
      final announcements = recordAnnouncements(tester);
      await pumpForm(tester, observers: [values]);

      await tester.enterText(find.byType(TextField), '  Home Assistant ');
      await tester.tap(find.text(en.apiTokenPresetTasks));
      await tester.pump();
      await tester.tap(find.text(en.apiTokenFormCreate));
      await tester.pumpAndSettle();

      final sent = harness.security.createdApiTokens.single;
      expect(sent.title, 'Home Assistant');
      expect(sent.permissions, {
        'labels': ['create', 'read_all', 'read_one'],
        'projects': ['read_all', 'read_one'],
        'tasks': ['create', 'delete', 'read_all', 'read_one', 'update'],
      });
      expect(sent.expiresAt.isUtc, isTrue);
      expect(
        sent.expiresAt.difference(DateTime.now()).inHours,
        closeTo(30 * 24, 1),
      );

      final secret = fakeApiTokenSecret(1);
      expect(find.byType(OneTimeSecretView), findsOneWidget);
      expect(find.text(secret), findsOneWidget);
      expect(find.text(en.oneTimeSecretOnce), findsOneWidget);
      expect(harness.secureWindow.secure, isTrue);
      expect(
        announcements,
        contains('${en.oneTimeSecretApiTitle} ${en.oneTimeSecretOnce}'),
      );

      await tester.tap(find.text(en.oneTimeSecretCopy));
      await tester.pumpAndSettle();
      expect(harness.clipboard.copied, [secret]);
      expect(find.text(en.copiedToClipboard), findsOneWidget);

      await tester.tap(find.text(en.oneTimeSecretDone));
      await tester.pumpAndSettle();
      expect(find.byType(ApiTokensPage), findsOneWidget);
      expect(find.text('Home Assistant'), findsOneWidget);
      expect(harness.secureWindow.secure, isFalse);
      expect(find.text(secret), findsNothing);

      expect(logs.where((line) => line.contains(secret)), isEmpty);
      expect(values.values.where((value) => value.contains(secret)), isEmpty);
    });

    testWidgets('leaving without copying asks once', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();
      await tester.tap(find.text(en.apiTokenFormCreate));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.oneTimeSecretLeaveTitle), findsOneWidget);
      await tester.tap(find.text(en.oneTimeSecretStay));
      await tester.pumpAndSettle();
      expect(find.byType(OneTimeSecretView), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.oneTimeSecretLeaveTitle), findsNothing);
      expect(find.byType(ApiTokensPage), findsOneWidget);
      expect(harness.clipboard.copied, isEmpty);
    });

    testWidgets('a refusal stays on the form and says why', (tester) async {
      harness.security.failures['createApiToken'] = const DomainError(
        400,
        code: 14002,
        message: 'The permission fly of group tasks is invalid.',
      );
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();
      await tester.tap(find.text(en.apiTokenFormCreate));
      await tester.pumpAndSettle();

      expect(
        find.text(
          en.accountSecurityRefused(
            'The permission fly of group tasks is invalid.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(OneTimeSecretView), findsNothing);
      expect(harness.secureWindow.changes, isEmpty);
    });

    testWidgets('a refusal is in view when the list was scrolled down', (
      tester,
    ) async {
      harness.security.failures['createApiToken'] = const DomainError(
        400,
        code: 14002,
        message: 'The permission fly of group tasks is invalid.',
      );
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();
      for (final group in ['Tasks', 'Other']) {
        await scrollToText(
          tester,
          find.byTooltip(en.apiTokenFormShowGroup(group)),
        );
        await tester.tap(find.byTooltip(en.apiTokenFormShowGroup(group)));
        await tester.pumpAndSettle();
      }
      await scrollToText(tester, groupBox('Routes'));

      await tester.tap(find.widgetWithText(TextButton, en.apiTokenFormCreate));
      await tester.pumpAndSettle();

      expect(
        find
            .text(
              en.accountSecurityRefused(
                'The permission fly of group tasks is invalid.',
              ),
            )
            .hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('the list and the settings re-read when the app was opened '
        'again during the form', (tester) async {
      await harness.pump(tester);
      await scrollToIn(
        tester,
        AccountSettingsPage,
        find.text(en.accountSettingsApiTokens),
      );
      await tester.tap(find.text(en.accountSettingsApiTokens));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(en.apiTokensNew));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Home Assistant');
      await tester.tap(find.text(en.apiTokenPresetReadOnly));
      await tester.pump();

      await reportRouteFromPlatform(tester);
      await tester.tap(find.text(en.apiTokenFormCreate));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.oneTimeSecretCopy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.oneTimeSecretDone));
      await tester.pumpAndSettle();
      expect(find.text('Home Assistant'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await scrollToIn(
        tester,
        AccountSettingsPage,
        find.text(en.accountSettingsApiTokens),
      );
      expect(find.text(en.accountSettingsApiTokensCount(1)), findsOneWidget);
    });

    testWidgets('leaving a started form asks first', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Script');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.apiTokenFormDiscardBody), findsOneWidget);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(find.byType(ApiTokensPage), findsOneWidget);
      expect(harness.security.createdApiTokens, isEmpty);
    });

    testWidgets('permissions that cannot be read offer a retry', (
      tester,
    ) async {
      harness.security.failures['apiPermissions'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpForm(tester);
      expect(find.text(en.dataFailureLoadTitle), findsOneWidget);

      harness.security.failures.clear();
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.text(en.apiTokenFormPresets), findsOneWidget);
    });

    testWidgets('is in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await harness.pump(tester, location: AppRoutes.accountApiTokenNew);

      expect(find.text(de.apiTokenFormTitle), findsOneWidget);
      expect(find.text(de.apiTokenPresetTasks), findsOneWidget);
    });
  });
}
