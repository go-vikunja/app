import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The link-share endpoints a guest's session needs. Throws
/// `VikunjaFailure`, see [LinkShareAuthClient].
abstract interface class LinkShareGateway {
  Future<LinkShareAuth> authenticate(
    ServerConnection connection,
    String hash, {
    String? password,
  });

  Future<LinkShareToken> renew(ServerConnection connection, String token);
}

final class ApiLinkShareGateway implements LinkShareGateway {
  /// The Dio must neither carry an auth interceptor nor log bodies.
  new(this._dio);

  final Dio _dio;

  @override
  Future<LinkShareAuth> authenticate(
    ServerConnection connection,
    String hash, {
    String? password,
  }) => LinkShareAuthClient(
    _dio,
    connection,
  ).authenticate(hash, password: password);

  @override
  Future<LinkShareToken> renew(ServerConnection connection, String token) =>
      LinkShareAuthClient(_dio, connection).renew(token);
}
