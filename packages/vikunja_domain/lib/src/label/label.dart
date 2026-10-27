import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';

@immutable
final class Label {
  const new({
    required this.id,
    required this.title,
    this.description = '',
    this.hexColor = '',
    this.createdBy,
    this.created,
    this.updated,
  });

  /// The server's limit in code points; titles above it are refused.
  static const maxTitleLength = 250;

  final int id;
  final String title;
  final String description;

  /// Six hex digits without `#`, or empty.
  final String hexColor;
  final User? createdBy;
  final DateTime? created;
  final DateTime? updated;

  @override
  bool operator ==(Object other) =>
      other is Label &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.hexColor == hexColor &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(id, title, description, hexColor, updated);

  @override
  String toString() => 'Label($id)';
}
