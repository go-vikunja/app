import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The 404 was captured by tool/capture_link_share_fixtures.dart; the test
// server has no licence for invites, so the 200 is the shape of
// `pkg/routes/api/v2/invite_links.go` (2.7.1).
const _url = '$testServerRoot/api/v2/invite-links/check';
final String _token = 'Q7' * 32;

InviteLinksPort _port(Map<String, FakeRoute> routes, {bool hasV2 = true}) =>
    createInviteLinksPort(
      dio: fakeDio(routes),
      connection: testConnection(hasV2: hasV2),
    );

void main() {
  test('the name, the teams and whether confirmation is skipped', () async {
    final dio = fakeDio({
      _url: json({
        r'$schema': 'http://localhost:34527/api/v2/schemas/X.json',
        'name': 'Spring intake',
        'teams': [
          {'id': 3, 'name': 'Kitchen'},
          {'id': 5, 'name': 'Garden'},
          {'id': 'odd'},
        ],
        'skip_email_confirm': true,
      }),
    });

    final preview = await createInviteLinksPort(
      dio: dio,
      connection: testConnection(),
    ).check(_token);

    final request = adapterOf(dio).requests.single;
    expect(request.method, 'POST');
    expect(request.followRedirects, isFalse);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(adapterOf(dio).decodedBodies, [
      {'token': _token},
    ]);
    expect(
      preview,
      InvitePreview(
        name: 'Spring intake',
        teams: const [
          InviteTeam(id: 3, name: 'Kitchen'),
          InviteTeam(id: 5, name: 'Garden'),
        ],
        skipsEmailConfirmation: true,
      ),
    );
  });

  test('teams and the flag may be missing', () async {
    final preview = await _port({
      _url: json({'name': 'Plain', 'teams': null}),
    }).check(_token);

    expect(preview, InvitePreview(name: 'Plain'));
  });

  test('invalid, expired, used up or unlicensed is 404 code 2005', () async {
    await expectLater(
      _port({_url: capturedFixture('invites/v2_invite_check_invalid_2.7.0')})
          .check(_token),
      throwsA(isA<NotFound>().having((f) => f.code, 'code', 2005)),
    );
  });

  test('a server without the route is a NotFound without a code', () async {
    await expectLater(
      _port({_url: errorFixture('v2_404_route_2.7.0')}).check(_token),
      throwsA(isA<NotFound>().having((f) => f.routeAbsent, 'absent', isTrue)),
    );
  });

  test('without /api/v2 nothing is asked', () async {
    final dio = fakeDio({});

    await expectLater(
      createInviteLinksPort(
        dio: dio,
        connection: testConnection(hasV2: false),
      ).check(_token),
      throwsA(isA<NotFound>().having((f) => f.routeAbsent, 'absent', isTrue)),
    );
    expect(adapterOf(dio).requests, isEmpty);
  });

  test('an answer that is not an object is unexpected', () async {
    await expectLater(
      _port({
        _url: json(['no']),
      }).check(_token),
      throwsA(isA<UnexpectedResponse>()),
    );
  });
}
