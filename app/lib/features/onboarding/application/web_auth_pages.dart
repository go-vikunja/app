import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// The web's form that mails a link to set a new password, which the app
/// never takes itself (D14).
Uri passwordResetPageUri(ServerConnection connection) => webFrontendBase(
  serverRoot: connection.rootUri,
  frontendUrl: connection.info.frontendUrl,
).resolve('get-password-reset');
