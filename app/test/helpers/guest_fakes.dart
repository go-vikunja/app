import 'dart:async';
import 'dart:convert';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';

import 'auth_fakes.dart';

/// A hash shaped like the server's (40 letters and digits), and as
/// obviously fake as the fixtures' scrubbed ones.
final String fakeShareHash = 'x' * 40;

/// A link-share token (`type` 2) as the server would issue it at
/// [issuedAt] (server time); signed with nothing, like [fakeJwt].
LinkShareToken issueLinkShareToken({
  required DateTime issuedAt,
  int shareId = 84,
  int projectId = 1378,
  Permission permission = Permission.read,
  Duration lifetime = const Duration(hours: 72),
}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final jwt = [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({
      'type': 2,
      'id': shareId,
      'hash': fakeShareHash,
      'project_id': projectId,
      'permission': permission.value,
      'sharedByID': 7,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': issuedAt.add(lifetime).millisecondsSinceEpoch ~/ 1000,
      'nonce': '${issuedAt.microsecondsSinceEpoch}-${++_tokenCounter}',
    }),
    'c2lnbmF0dXJl',
  ].join('.');
  return LinkShareToken(jwt, LinkShareClaims.tryParse(jwt)!);
}

var _tokenCounter = 0;

/// What `POST /shares/{hash}/auth` answers for [token].
LinkShareAuth linkShareAuthFor(
  LinkShareToken token, {
  Permission permission = Permission.read,
  String? name = 'Helper',
}) => LinkShareAuth(
  token: token,
  projectId: token.claims.projectId,
  permission: permission,
  name: name,
);

/// The link-share endpoints: each call is recorded (the hash only as
/// whether it was the expected one, the password as given) and answered
/// by its handler; without one it fails the test.
final class FakeLinkShareGateway implements LinkShareGateway {
  Future<LinkShareAuth> Function(String hash, String? password)? onAuthenticate;
  Future<LinkShareToken> Function(String token)? onRenew;

  /// `(hash, password)` per authentication, in order.
  final List<(String, String?)> authentications = [];
  final List<String> renewedTokens = [];
  final List<ServerConnection> connections = [];

  @override
  Future<LinkShareAuth> authenticate(
    ServerConnection connection,
    String hash, {
    String? password,
  }) {
    connections.add(connection);
    authentications.add((hash, password));
    final handler = onAuthenticate;
    if (handler == null) throw StateError('no share authentication expected');
    return handler(hash, password);
  }

  @override
  Future<LinkShareToken> renew(ServerConnection connection, String token) {
    connections.add(connection);
    renewedTokens.add(token);
    final handler = onRenew;
    if (handler == null) throw StateError('no token renewal expected');
    return handler(token);
  }

  /// Holds the next authentication open until the returned completer
  /// completes, so a test sees the screen while it is on its way.
  Completer<void> holdNextAuthentication() {
    final release = Completer<void>();
    final handler = onAuthenticate;
    onAuthenticate = (hash, password) async {
      onAuthenticate = handler;
      await release.future;
      if (handler == null) throw StateError('no share authentication expected');
      return await handler(hash, password);
    };
    return release;
  }

  /// A share that grants [token] to [fakeShareHash], with [password] when
  /// it has one (13001 without, 13002 for another).
  void serve(LinkShareToken token, {String? password, String? name}) {
    onAuthenticate = (hash, given) async {
      if (hash != fakeShareHash) throw const LinkShareGone(code: 3006);
      if (password != null && (given == null || given.isEmpty)) {
        throw const DomainError(412, code: 13001);
      }
      if (password != null && given != password) {
        throw const Forbidden(code: 13002);
      }
      return linkShareAuthFor(
        token,
        permission: token.claims.permission ?? Permission.read,
        name: name,
      );
    };
  }
}

extension GuestSeeding on AuthFakes {
  LinkShareStore get linkShareStore => LinkShareStore(secureStore);

  /// Stores a guest as a previous app run would have left it: the registry
  /// entry, the hash and, unless null, [token].
  Future<RegisteredAccount> seedGuest(
    ServerConnection connection, {
    required LinkShareToken? token,
    int shareId = 84,
    int projectId = 1378,
    String displayName = 'Garden',
    String? shareName = 'Helper',
    bool needsReauth = false,
    bool activate = true,
  }) async {
    final entry = RegisteredAccount(
      account: Account.linkShare(
        id: linkShareAccountIdFor(connection.rootUri, shareId),
        serverRoot: connection.rootUri,
        shareId: shareId,
        projectId: projectId,
        shareName: shareName,
        displayName: displayName,
        addedAt: DateTime.utc(2026, 10, 26),
        needsReauth: needsReauth,
      ),
      connection: connection,
    );
    await AccountRegistry(preferences).upsert(entry, activate: activate);
    if (token == null) {
      await secureStore.write(LinkShareStore.hashKey(entry.id), fakeShareHash);
    } else {
      await linkShareStore.write(
        entry.id,
        hash: fakeShareHash,
        token: token.jwt,
      );
    }
    return entry;
  }
}
