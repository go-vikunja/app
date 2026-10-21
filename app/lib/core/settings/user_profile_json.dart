import 'dart:convert';

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
  if (json case {'id': final int id, 'username': final String username}
      when username.isNotEmpty) {
    return UserProfile(
      id: id,
      username: username,
      name: switch (json['name']) {
        final String name => name,
        _ => '',
      },
      isLocalUser: json['is_local_user'] != false,
      authProvider: switch (json['auth_provider']) {
        final String provider => provider,
        _ => '',
      },
      pendingEmail: switch (json['pending_email']) {
        final String email when email.isNotEmpty => email,
        _ => null,
      },
      updated: switch (json['updated']) {
        final String updated => DateTime.tryParse(updated)?.toUtc(),
        _ => null,
      },
      deletionScheduledAt: switch (json['deletion_scheduled_at']) {
        final String scheduled => DateTime.tryParse(scheduled)?.toUtc(),
        _ => null,
      },
    );
  }
  return null;
}
