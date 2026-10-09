import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

part 'current_server.g.dart';

final _log = Logger('CurrentServer');

/// The server the user confirmed, including consent to plain http.
@Riverpod(keepAlive: true)
class CurrentServer extends _$CurrentServer {
  @override
  ServerConnection? build() => null;

  void select(ServerConnection connection) {
    _log.info(
      'Using ${describeUriForLog(connection.rootUri)} '
      '(${connection.info.version?.raw ?? 'unknown version'}, '
      '${connection.capabilities.tier.name})',
    );
    state = connection;
  }

  void clear() => state = null;
}
