import 'dart:convert';

import 'package:vikunja_api/vikunja_api.dart' show parseUserProfile;
import 'package:vikunja_domain/vikunja_domain.dart';

/// `UserProfile` as the sync stores it in `sync_state`. Reading never
/// fails: a value this version cannot read is null, as before the first
/// sync, until the next sync writes it again.
String encodeUserProfile(UserProfile profile) => jsonEncode({
  'id': profile.id,
  'username': profile.username,
  'name': profile.name,
  'is_local_user': profile.isLocalUser,
  'auth_provider': profile.authProvider,
  'pending_email': ?profile.pendingEmail,
  'updated': ?profile.updated?.toUtc().toIso8601String(),
  'deletion_scheduled_at': ?profile.deletionScheduledAt
      ?.toUtc()
      .toIso8601String(),
});

UserProfile? decodeUserProfile(String? stored) {
  final Object? json;
  try {
    json = stored == null ? null : jsonDecode(stored);
  } on FormatException {
    return null;
  }
  return switch (parseUserProfile(json)) {
    final profile? when profile.username.isNotEmpty => profile,
    _ => null,
  };
}
