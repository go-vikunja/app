import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

typedef ConnectHandler = Future<ServerConnection> Function(String input);

class FakeServerConnector implements ServerConnector {
  new([ConnectHandler? handler])
    : handler = handler ?? ((_) => Completer<ServerConnection>().future);

  factory succeeding(ServerConnection connection) =>
      FakeServerConnector((_) async => connection);

  factory failing(Object error) =>
      FakeServerConnector((_) => Future.error(error));

  ConnectHandler handler;
  final List<String> inputs = [];
  final List<CancelToken?> cancelTokens = [];

  @override
  Future<ServerConnection> connect(String input, {CancelToken? cancelToken}) {
    inputs.add(input);
    cancelTokens.add(cancelToken);
    final result = handler(input);
    if (cancelToken == null) return result;
    // Like DioServerConnector, a cancelled request fails with the DioException.
    return Future.any([
      result,
      cancelToken.whenCancel.then<ServerConnection>((error) => throw error),
    ]);
  }
}

class FakeExternalLinkOpener implements ExternalLinkOpener {
  new({this.succeeds = true});

  final bool succeeds;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}
