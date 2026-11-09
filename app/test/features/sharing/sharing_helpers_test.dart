import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/sharing/application/access_cleanup.dart';
import 'package:vikunja_mobile/features/sharing/application/link_qr.dart';
import 'package:vikunja_mobile/features/sharing/application/link_share_links.dart';
import 'package:vikunja_mobile/features/sharing/application/share_candidates.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_qr_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_clipboard.dart';
import 'package:vikunja_mobile/features/sharing/presentation/qr_code_view.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';

void main() {
  final hash = 'a' * 40;

  group('the QR code', () {
    test('fits a link on a long frontend address into version 10', () {
      final link =
          'https://tasks.example.org/${'p' * 60}/share/$hash/auth?view=12';
      final image = linkQrImage(link);
      expect(image, isNotNull);
      expect(image!.typeNumber, lessThanOrEqualTo(linkQrMaxVersion));
    });

    test('refuses a link that would need more than version 10', () {
      expect(
        linkQrImage('https://tasks.example.org/${'p' * 200}/share/$hash/auth'),
        isNull,
      );
    });

    Future<void> pumpSheet(WidgetTester tester, Uri url) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(body: LinkQrSheet(url: url)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the code dark on white, also in dark mode, with the '
        'link below', (tester) async {
      final url = Uri.parse('https://tasks.example.org/share/$hash/auth');
      await pumpSheet(tester, url);

      expect(find.byType(QrCodeView), findsOneWidget);
      expect(find.bySemanticsLabel(en.linkShareQrSemantics), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LinkShareText),
          matching: find.text(url.toString()),
        ),
        findsOneWidget,
      );
      final size = tester.getSize(find.byType(QrCodeView));
      expect(size.width, greaterThanOrEqualTo(200));
    });

    testWidgets('says when the link is too long, and keeps the link', (
      tester,
    ) async {
      final url = Uri.parse(
        'https://tasks.example.org/${'p' * 200}/share/$hash/auth',
      );
      await pumpSheet(tester, url);

      expect(find.byType(QrCodeView), findsNothing);
      expect(find.text(en.linkShareQrTooLong), findsOneWidget);
      expect(find.text(url.toString()), findsOneWidget);
    });
  });

  group('the link', () {
    final share = LinkShare(id: 1, hash: hash, permission: Permission.read);
    final views = [
      sampleListView(id: 12, projectId: 1),
      sampleKanbanView(id: 11, projectId: 1, position: 50),
    ];

    test('opens the first view in the web order unless another was picked', () {
      final ordered = linkViewChoices(
        sampleProject(id: 1, title: 'P', views: views),
      );
      expect(ordered.map((view) => view.id), [11, 12]);
      expect(linkViewIdFor(ordered, null), 11);
      expect(linkViewIdFor(ordered, 12), 12);
      expect(linkViewIdFor(ordered, 99), 11);
      expect(linkViewIdFor(const [], 12), isNull);
    });

    test('goes to the frontend, never an http one for an https server', () {
      final connection = fullServer270();
      expect(
        linkShareUriFor(
          AccountLinkBases.of(connection),
          share,
          viewId: 11,
        ).toString(),
        'https://tasks.example.org/vikunja/share/$hash/auth?view=11',
      );
      expect(
        linkShareUriFor(
          AccountLinkBases(
            serverRoot: Uri.parse('https://tasks.example.org'),
            frontendUrl: Uri.parse('http://tasks.example.org/web/'),
          ),
          share,
        ).toString(),
        'https://tasks.example.org/share/$hash/auth',
      );
    });
  });

  test('people already with access are not offered', () {
    const ben = User(id: 3, username: 'ben', name: 'Ben');
    expect(
      peopleNotToOffer(
        shares: const [
          ProjectUserShare(user: ben, permission: Permission.read),
        ],
        currentUserId: 7,
        ownerId: 2,
      ),
      {7, 2, 3},
    );
  });

  group('the words', () {
    test('for refusals, by the server codes', () {
      final cases = <(Object, ShareChange, String)>[
        (
          const NetworkFailure(NetworkProblem.timeout),
          ShareChange.addPerson,
          en.shareFailureUnconfirmed,
        ),
        (
          const NetworkFailure(NetworkProblem.unreachable),
          ShareChange.addPerson,
          en.shareFailureOffline,
        ),
        (
          const DomainError(409, code: 7002),
          ShareChange.addPerson,
          en.shareFailureAlreadyShared,
        ),
        (
          const NotFound(code: 1005),
          ShareChange.addPerson,
          en.shareFailureUnknownUser,
        ),
        (
          const Forbidden(code: 7003),
          ShareChange.removePerson,
          en.shareFailureGone,
        ),
        (
          const Forbidden(code: 6007),
          ShareChange.removeTeam,
          en.shareFailureGone,
        ),
        (
          const NotFound(code: 3006),
          ShareChange.deleteLink,
          en.shareFailureGone,
        ),
        (
          const DomainError(409, code: 6004),
          ShareChange.addTeam,
          en.shareFailureTeamAlreadyShared,
        ),
        (
          const NotFound(code: 6002),
          ShareChange.addTeam,
          en.shareFailureUnknownTeam,
        ),
        (
          const NotFound(),
          ShareChange.createLink,
          en.shareFailureLinkSharingOff,
        ),
        (const Forbidden(), ShareChange.changePerson, en.shareFailureForbidden),
        (
          const ValidationFailed(),
          ShareChange.createLink,
          en.shareFailureInvalid,
        ),
        (
          const DomainError(400, code: 2004),
          ShareChange.changeTeam,
          en.shareFailureInvalid,
        ),
        (const NotFound(code: 3001), ShareChange.addPerson, en.projectGone),
        (const NotFound(code: 3018), ShareChange.createLink, en.projectGone),
        (StateError('boom'), ShareChange.addPerson, en.shareFailureGeneric),
      ];
      for (final (error, change, text) in cases) {
        expect(shareFailureText(en, error, change), text, reason: '$error');
      }
    });

    test('for removing access, with the cleanup list from 2.7 on', () {
      expect(
        accessRemovalBody(en, loss: 'Gone.', self: false, listsCleanup: false),
        'Gone.',
      );
      expect(
        accessRemovalBody(en, loss: 'Gone.', self: true, listsCleanup: true),
        [
          'Gone.',
          '',
          en.shareCleanupSelfIntro,
          '• ${en.shareCleanupSelfAssignments}',
          '• ${en.shareCleanupSelfSubscriptions}',
          '• ${en.shareCleanupSelfWebhooks}',
        ].join('\n'),
      );
      expect(serverCleansUpAccess(fullServer270()), isTrue);
      expect(serverCleansUpAccess(oauthServer230()), isFalse);
      expect(serverCleansUpAccess(null), isFalse);
    });
  });
}
