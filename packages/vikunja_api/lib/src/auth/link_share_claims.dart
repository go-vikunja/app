import 'dart:convert';

import 'package:meta/meta.dart';
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
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final Object? payload;
    try {
      payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } on FormatException {
      return null;
    }
    if (payload is! Map<String, Object?>) return null;

    final shareId = _integer(payload['id']);
    final projectId = _integer(payload['project_id']);
    final expiresAt = _time(payload['exp']);
    if (_integer(payload['type']) != _linkShareTokenType ||
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
      permission: Permission.fromValue(_integer(payload['permission'])),
      sharedById: _integer(payload['sharedByID']),
      issuedAt: _time(payload['iat']),
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

int? _integer(Object? value) => switch (value) {
  final int integer => integer,
  final double number when number == number.truncateToDouble() =>
    number.toInt(),
  _ => null,
};

// The range DateTime can represent.
const _maxSeconds = 8640000000000;

DateTime? _time(Object? value) => switch (value) {
  final num seconds when seconds.isFinite && seconds.abs() <= _maxSeconds =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true),
  _ => null,
};
