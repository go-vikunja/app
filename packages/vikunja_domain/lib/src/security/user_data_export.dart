import 'package:meta/meta.dart';

/// The user's latest data export, ready to download until [expires]. The
/// server has no "in progress" state: the previous export shows until a new
/// one is written, and its hourly cleanup can drop one early.
@immutable
final class UserDataExport {
  const new({
    required this.id,
    required this.size,
    required this.expires,
    this.created,
  });

  /// The export file's id; a new export has a new one.
  final int id;

  /// Bytes.
  final int size;
  final DateTime expires;
  final DateTime? created;

  bool isExpiredAt(DateTime now) => !expires.isAfter(now);

  @override
  bool operator ==(Object other) =>
      other is UserDataExport &&
      other.id == id &&
      other.size == size &&
      other.expires == expires &&
      other.created == created;

  @override
  int get hashCode => Object.hash(id, size, expires, created);

  @override
  String toString() => 'UserDataExport($id)';
}
