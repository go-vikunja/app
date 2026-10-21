import 'package:meta/meta.dart';

/// A CalDAV token as the list answers it: never with its value. Tokens have
/// neither a title nor an expiry.
@immutable
final class CaldavToken {
  const new({required this.id, this.created});

  final int id;
  final DateTime? created;

  @override
  bool operator ==(Object other) =>
      other is CaldavToken && other.id == id && other.created == created;

  @override
  int get hashCode => Object.hash(id, created);

  @override
  String toString() => 'CaldavToken($id)';
}

/// The create answer, the only one that carries the token's value.
final class CreatedCaldavToken {
  const new({required this.token, required this.secret});

  final CaldavToken token;

  /// 64 letters and digits, the password for CalDAV's Basic auth; shown
  /// once, never stored or logged.
  final String secret;

  @override
  String toString() => 'CreatedCaldavToken(${token.id}, [redacted])';
}
