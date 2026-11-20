@Tags(['contract'])
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/guest_fakes.dart';
import 'helpers.dart';

// The session check reads a guest's pseudo user: a deleted share's token
// gets a 401 on v2, a 400 code 13003 on v1 from 2.7, and before it a 500 on
// v1, which a renewal of the token confirms as gone. Each way ends the
// guest at the check, which leaves a guest whose share is there alone. One
// share authentication.
void main() {
  test(
    'the session check ends a guest whose share was deleted, on the API '
    'version the app reads over',
    skip: contractSkip,
    () async {
      final dio = contractDio();
      addTearDown(() => dio.close(force: true));
      final connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      final owner = await registerAndLogin(dio, connection);
      final seeder = Seeder(dio, connection, owner);
      final projectId = await seeder.create('/projects', {
        'title': 'Checked garden',
      });
      final sharing = createProjectSharingPort(
        dio: createAuthenticatedDio(
          base: dio,
          connection: connection,
          tokens: StaticJwt(owner.jwt),
        ),
        connection: connection,
      );
      final share = await sharing.createLinkShare(
        projectId,
        const NewLinkShare(permission: Permission.write),
      );
      final auth = await patiently(
        () => LinkShareAuthClient(dio, connection).authenticate(share.hash),
      );
      final stores = AuthFakes();
      final guest = await stores.seedGuest(
        connection,
        token: auth.token,
        shareId: share.id,
        projectId: projectId,
      );
      Future<ServerConnection?> connectionFor(String id) async =>
          (await stores.registry.find(id))?.connection;
      Future<bool> needsReauth() async =>
          (await stores.registry.find(guest.id))!.account.needsReauth;
      SessionCheck newCheck() => SessionCheck(
        sessions: SessionManagers(
          tokenStore: stores.tokenStore,
          clockOffsets: stores.clockOffsets,
          tokenGateway: stores.tokenGateway,
          connectionFor: connectionFor,
          markNeedsReauth: stores.registry.markNeedsReauth,
        ),
        linkShares: LinkShareSessions(
          store: stores.linkShareStore,
          gateway: ApiLinkShareGateway(dio),
          connectionFor: connectionFor,
          markNeedsReauth: stores.registry.markNeedsReauth,
        ),
        accountGateway: ApiAccountGateway(dio, logRequests: false),
      );

      await newCheck().check(guest);
      expect(await needsReauth(), isFalse);

      await despiteWriteRaces(
        () => sharing.deleteLinkShare(projectId, share.id),
      );
      await newCheck().check(guest);
      await pumpEventQueue();

      expect(await needsReauth(), isTrue);
    },
  );
}
