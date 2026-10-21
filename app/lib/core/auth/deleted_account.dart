import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';

final _log = Logger('DeletedAccount');

const userDoesNotExistCode = 1005;

/// Once the server has deleted the account, `GET /user` answers 404 code
/// 1005 while the access token keeps working for up to ten minutes; the
/// refresh fails at once. Refreshing then ends the session like any ended
/// session, so the app asks for a new sign-in instead of failing every
/// read. [readUser]'s failure stands when the refresh does not end it.
Future<T> endingSessionOfDeletedAccount<T>(
  SessionManager session,
  Future<T> Function() readUser,
) async {
  try {
    return await readUser();
  } on NotFound catch (failure) {
    if (failure.code != userDoesNotExistCode) rethrow;
    try {
      await session.refreshNow();
    } on SessionEnded {
      rethrow;
    } on Object catch (error) {
      _log.info('No refresh after a missing user: ${error.runtimeType}');
    }
    rethrow;
  }
}
