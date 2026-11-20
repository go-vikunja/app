import 'package:meta/meta.dart';
import 'package:vikunja_api/src/auth/jwt_payload.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The payload of a Vikunja link share JWT (`type` 2). The server signs it
/// and reads the share again on every request, so [permission] is only
/// what the share had when the token was issued.
@immutable
final class LinkShareClaims {
  const new({
    required this.shareId,
    required this.projectId,
    required this.expiresAt,
    this.permission,
    this.sharedById,
    this.issuedAt,
  });

  /// Null unless [token] is a well-formed link share JWT (`type` 2 with
  /// `id`, `project_id` and `exp`).
  static LinkShareClaims? tryParse(String token) {
    final payload = jwtPayload(token);
    if (payload == null) return null;

    final shareId = jwtInteger(payload['id']);
    final projectId = jwtInteger(payload['project_id']);
    final expiresAt = jwtTime(payload['exp']);
    if (jwtInteger(payload['type']) != _linkShareTokenType ||
        shareId == null ||
        shareId <= 0 ||
        projectId == null ||
        expiresAt == null) {
      return null;
    }
    return LinkShareClaims(
      shareId: shareId,
      projectId: projectId,
      expiresAt: expiresAt,
      permission: Permission.fromValue(jwtInteger(payload['permission'])),
      sharedById: jwtInteger(payload['sharedByID']),
      issuedAt: jwtTime(payload['iat']),
    );
  }

  static const _linkShareTokenType = 2;

  final int shareId;
  final int projectId;
  final Permission? permission;
  final int? sharedById;

  /// Server time.
  final DateTime? issuedAt;

  /// Server time.
  final DateTime expiresAt;

  /// The pseudo user the server shows for the guest as `created_by` and
  /// `author`.
  int get guestUserId => -shareId;

  /// Never with the hash, which the token carries too.
  @override
  String toString() => 'LinkShareClaims(share: $shareId, project: $projectId)';
}
