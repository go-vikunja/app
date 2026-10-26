import 'package:dio/dio.dart';
import 'package:vikunja_api/src/invites/invite_links_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Registration invites an admin hands out (2.7.0 and later, `/api/v2`
/// only, licensed as the pro feature `user_invites`). Public: no account
/// is needed. The token is a secret: requests carrying it are never logged.
abstract interface class InviteLinksPort {
  /// `POST /api/v2/invite-links/check`. An invalid, expired, used up or
  /// unlicensed invite is a `NotFound` code 2005; a server without the
  /// route (before 2.7.0, local accounts off, or no `/api/v2` at all, which
  /// is answered without a request) a `NotFound` without a code.
  Future<InvitePreview> check(String token);
}

/// Over a [dio] without an auth interceptor; it may be the one the
/// connection was probed with.
InviteLinksPort createInviteLinksPort({
  required Dio dio,
  required ServerConnection connection,
}) => InviteLinksApi(dio: dio, connection: connection);
