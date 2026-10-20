import 'package:meta/meta.dart';

/// What the app sends to create a project; the server assigns the id, the
/// position (id × 65536) and four default views.
@immutable
final class NewProject {
  const new({
    required this.title,
    this.parentProjectId = 0,
    this.hexColor = '',
  });

  /// 1 to 250 characters.
  final String title;

  /// 0 for the top level.
  final int parentProjectId;

  /// Six hex digits without `#`, or empty.
  final String hexColor;

  @override
  bool operator ==(Object other) =>
      other is NewProject &&
      other.title == title &&
      other.parentProjectId == parentProjectId &&
      other.hexColor == hexColor;

  @override
  int get hashCode => Object.hash(title, parentProjectId, hexColor);

  /// Without the title, which is user text.
  @override
  String toString() => 'NewProject(parentProjectId: $parentProjectId)';
}
