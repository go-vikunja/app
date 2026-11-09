import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'connection_refresh.g.dart';

final _log = Logger('ConnectionRefresh');

@Riverpod(keepAlive: true)
ConnectionRefresh connectionRefresh(Ref ref) => ConnectionRefresh(
  registry: ref.watch(accountRegistryProvider),
  // Built on first use: the connector brings the app's HTTP client along.
  connector: () => ref.read(serverConnectorProvider),
  clock: ref.watch(clockProvider),
);

/// Reads the server's `/info` again while signed in, so a server updated
/// since the sign-in shows its new version and capabilities; the API ports
/// are rebuilt on a changed version and gate their routes on it. It runs
/// the first time the active account is in front after the app starts,
/// then at most every [interval] while it is in front, and after a probe
/// that did not reach the server again after [retryAfterFailure]. A
/// failure is logged and keeps the stored connection.
final class ConnectionRefresh {
  new({
    required this._registry,
    required this._connector,
    required this._clock,
    this.interval = const Duration(hours: 6),
    this.retryAfterFailure = const Duration(minutes: 5),
  });

  final AccountRegistry _registry;
  final ServerConnector Function() _connector;
  final DateTime Function() _clock;
  final Duration interval;
  final Duration retryAfterFailure;
  final _dueAt = <String, DateTime>{};
  final _inFlight = <String>{};

  /// [accountId] is active and the app in front. Completes when a refresh
  /// it started is done.
  Future<void> onForeground(String accountId) async {
    if (_dueAt[accountId] case final due? when _clock().isBefore(due)) {
      return;
    }
    if (!_inFlight.add(accountId)) return;
    try {
      final outcome = await _refresh(accountId);
      _dueAt[accountId] = _clock().add(
        outcome == _Outcome.unreached ? retryAfterFailure : interval,
      );
    } finally {
      _inFlight.remove(accountId);
    }
  }

  /// Whether a changed connection was stored. Never throws.
  Future<bool> refresh(String accountId) async =>
      await _refresh(accountId) == _Outcome.stored;

  Future<_Outcome> _refresh(String accountId) async {
    final ServerConnection fresh;
    try {
      final stored = (await _registry.find(accountId))?.connection;
      if (stored == null) return _Outcome.kept;
      fresh = await _connector().connect(stored.rootUri.toString());
    } on Object catch (error) {
      _logNotRefreshed(accountId, error);
      return _Outcome.unreached;
    }
    try {
      final written = await _registry.updateConnection(
        accountId,
        (current) => _refreshed(current, fresh),
      );
      if (!written) return _Outcome.kept;
      _log.info(
        'Server of account $accountId now reports '
        '${fresh.info.version?.display ?? fresh.info.rawVersion}',
      );
      return _Outcome.stored;
    } on Object catch (error) {
      _logNotRefreshed(accountId, error);
      return _Outcome.kept;
    }
  }

  static void _logNotRefreshed(String accountId, Object error) => _log.info(
    'Server info of account $accountId not refreshed: ${error.runtimeType}',
  );
}

enum _Outcome { stored, kept, unreached }

/// [stored] with [fresh]'s `/info`, or null when nothing changed or [fresh]
/// fails a guard. As at a new sign-in, another root would be another
/// account and an unsupported server cannot be used. The API versions are
/// the union of both: a refresh may add one, and only a new sign-in may
/// drop one. A probe of `/api/v1` or `/api/v2` that timed out or met a
/// proxy's error page would otherwise take away what the account uses (v1
/// carries the attachment previews) until the next refresh.
ServerConnection? _refreshed(ServerConnection stored, ServerConnection fresh) {
  if (fresh.rootUri != stored.rootUri || !fresh.capabilities.isSupported) {
    return null;
  }
  final apiVersions = {...stored.apiVersions, ...fresh.apiVersions};
  final unchanged =
      setEquals(apiVersions, stored.apiVersions) &&
      jsonEncode(serverInfoToJson(fresh.info)) ==
          jsonEncode(serverInfoToJson(stored.info));
  if (unchanged) return null;
  return ServerConnection(
    rootUri: stored.rootUri,
    apiVersions: Set.unmodifiable(apiVersions),
    info: fresh.info,
    capabilities: ServerCapabilities.derive(
      info: fresh.info,
      apiVersions: apiVersions,
    ),
  );
}
