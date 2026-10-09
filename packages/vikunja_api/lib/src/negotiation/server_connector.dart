import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/negotiation/info_probe.dart';
import 'package:vikunja_api/src/negotiation/probe_classifier.dart';
import 'package:vikunja_api/src/negotiation/server_address.dart';
import 'package:vikunja_api/src/negotiation/transport_failure.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

abstract interface class ServerConnector {
  /// Throws a [ServerConnectionFailure] when no Vikunja server answers, and
  /// rethrows the [DioException] when [cancelToken] cancels.
  Future<ServerConnection> connect(String input, {CancelToken? cancelToken});
}

/// Probes `/api/v2/info` and `/api/v1/info` of each candidate address: the
/// address as typed (https first when no scheme was typed, then http) and,
/// when no port was typed, port 3456 like the web frontend.
///
/// A candidate starts when the one before it could not connect, or
/// [candidateStagger] after that one started, but outcomes are used strictly
/// in candidate order. The native adapters wait [probeTimeout] for connecting
/// plus [probeTimeout] for the response, so an address where nothing answers
/// fails after at most 3 × [candidateStagger] + 2 × [probeTimeout] (17.5 s by
/// default). A server that answers can add a followed redirect, a v2 retry or
/// a walk up from a web app route, one probe timeout each.
final class DioServerConnector implements ServerConnector {
  new(
    this._dio, {
    this.probeTimeout = const Duration(seconds: 5),
    this.candidateStagger = const Duration(milliseconds: 2500),
  });

  static const vikunjaDefaultPort = 3456;

  final Dio _dio;
  final Duration probeTimeout;
  final Duration candidateStagger;

  @override
  Future<ServerConnection> connect(
    String input, {
    CancelToken? cancelToken,
  }) async {
    final address = normalizeServerAddress(input);
    final schemeRoots = [
      address.root,
      if (!address.hasExplicitScheme)
        address.root.replace(
          scheme: 'http',
          port: address.hasExplicitPort ? address.root.port : null,
        ),
    ];
    final candidates = {
      for (final schemeRoot in schemeRoots) ...[
        schemeRoot,
        if (!address.hasExplicitPort)
          schemeRoot.replace(port: vikunjaDefaultPort),
      ],
    }.toList();
    return await _ConnectAttempt(this, candidates, cancelToken).run();
  }
}

final class _ConnectAttempt {
  new(this._connector, this._candidates, this._callerToken);

  // Enough for deep web app routes such as /projects/1/settings/edit.
  static const _maxWalkUpLevels = 4;

  final DioServerConnector _connector;
  final List<Uri> _candidates;
  final CancelToken? _callerToken;
  final _probeToken = CancelToken();
  final _staggerTimers = <Timer>[];
  late final _started = List<Future<CandidateOutcome>?>.filled(
    _candidates.length,
    null,
  );
  final _failureAt = <Uri, ServerConnectionFailure>{};
  var _startsStopped = false;
  var _redirectFollowed = false;

  Future<ServerConnection> run() async {
    _throwIfCallerCancelled();
    unawaited(_callerToken?.whenCancel.then((_) => _probeToken.cancel()));
    try {
      return await _firstVikunja();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) _throwIfCallerCancelled();
      rethrow;
    } finally {
      _stopStarts();
      _probeToken.cancel();
    }
  }

  Future<ServerConnection> _firstVikunja() async {
    for (final (index, root) in _candidates.indexed) {
      _throwIfCallerCancelled();
      _start(index);
      final outcome = await _started[index]!;
      _throwIfCallerCancelled();
      // Once a server answered, other ports and a downgrade to http would
      // only reach a different service.
      final answered = switch (outcome) {
        CandidateFailed(:final failure) => !isConnectionLevel(failure),
        _ => true,
      };
      if (answered) _stopStarts();
      switch (await _settle(root, outcome)) {
        case VikunjaFound(:final connection):
          return connection;
        case CandidateFailed(:final failure):
          _failureAt[root] = failure;
          if (answered) throw failure;
      }
    }
    throw mostInformative(_failureAt.values);
  }

  void _start(int index) {
    if (index >= _candidates.length ||
        _started[index] != null ||
        _startsStopped ||
        (_callerToken?.isCancelled ?? false)) {
      return;
    }
    final outcome = _probe(_candidates[index])..ignore();
    _started[index] = outcome;
    _staggerTimers.add(
      Timer(_connector.candidateStagger, () => _start(index + 1)),
    );
    outcome.then((outcome) {
      if (outcome case CandidateFailed(:final failure)
          when isConnectionLevel(failure)) {
        _start(index + 1);
      }
    }).ignore();
  }

  void _stopStarts() {
    _startsStopped = true;
    for (final timer in _staggerTimers) {
      timer.cancel();
    }
  }

  Future<SettledOutcome> _settle(
    Uri root,
    CandidateOutcome outcome, {
    bool mayWalkUp = true,
  }) async {
    switch (outcome) {
      case V2Unverified(:final v1):
        final v2 = await _probeInfo(root, ApiVersion.v2);
        if (v2 is InfoTransportError) {
          return CandidateFailed(transportFailure(root, v2.exception));
        }
        return await _settle(root, classifyProbes(root, v2: v2, v1: v1));
      case RedirectsTo(
        root: final target,
        :final ifNotFollowed,
        :final looksLikeLogin,
      ):
        if (_failureAt[target] case final earlier?) {
          return CandidateFailed(earlier);
        }
        if (_redirectFollowed) return CandidateFailed(ifNotFollowed);
        _redirectFollowed = true;
        final followed = await _settle(
          target,
          await _probe(target),
          mayWalkUp: mayWalkUp,
        );
        return followed is CandidateFailed && looksLikeLogin
            ? CandidateFailed(ifNotFollowed)
            : followed;
      case CandidateFailed(
            failure: NotAVikunjaServer(),
            servesVikunjaWebApp: true,
          )
          when mayWalkUp && root.path.isNotEmpty:
        for (final ancestor in _ancestors(root).take(_maxWalkUpLevels)) {
          final found = await _settle(
            ancestor,
            await _probe(ancestor),
            mayWalkUp: false,
          );
          if (found is VikunjaFound) return found;
        }
        return outcome;
      case final SettledOutcome settled:
        return settled;
    }
  }

  Future<CandidateOutcome> _probe(Uri root) async {
    final [v2, v1] = await Future.wait([
      _probeInfo(root, ApiVersion.v2),
      _probeInfo(root, ApiVersion.v1),
    ]);
    return classifyProbes(root, v2: v2, v1: v1);
  }

  Future<InfoProbeResult> _probeInfo(Uri root, ApiVersion version) => probeInfo(
    _connector._dio,
    root,
    version,
    timeout: _connector.probeTimeout,
    cancelToken: _probeToken,
  );

  void _throwIfCallerCancelled() {
    if (_callerToken?.cancelError case final error?) throw error;
  }
}

Iterable<Uri> _ancestors(Uri root) sync* {
  var path = root.path;
  while (path.isNotEmpty) {
    path = path.substring(0, path.lastIndexOf('/'));
    yield root.replace(path: path);
  }
}
