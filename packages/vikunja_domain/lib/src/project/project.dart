import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

@immutable
final class Project {
  const new({
    required this.id,
    required this.title,
    this.description = '',
    this.identifier = '',
    this.hexColor = '',
    this.parentProjectId = 0,
    this.isArchived = false,
    this.isFavorite = false,
    this.position = 0,
    this.owner,
    this.views = const [],
    this.created,
    this.updated,
  });

  /// The Favorites pseudo project; it only appears in the project list.
  static const favoritesId = -1;

  final int id;
  final String title;

  /// HTML.
  final String description;

  /// Up to 10 characters; prefix of task identifiers (`PROJ-12`).
  final String identifier;

  /// Six hex digits without `#`, or empty.
  final String hexColor;

  /// 0 for a top-level project.
  final int parentProjectId;
  final bool isArchived;
  final bool isFavorite;
  final double position;
  final User? owner;
  final List<ProjectView> views;
  final DateTime? created;
  final DateTime? updated;

  bool get isTopLevel => parentProjectId == 0;

  /// Negative ids are pseudo projects: Favorites and saved filters.
  bool get isPseudo => id < 0;

  bool get isFavoritesPseudo => id == favoritesId;

  /// Saved filter `n` is listed as project `-n - 1`.
  int? get savedFilterId => id < favoritesId ? -id - 1 : null;

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.identifier == identifier &&
      other.hexColor == hexColor &&
      other.parentProjectId == parentProjectId &&
      other.isArchived == isArchived &&
      other.isFavorite == isFavorite &&
      other.position == position &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    identifier,
    hexColor,
    parentProjectId,
    isArchived,
    isFavorite,
    position,
    updated,
  );

  @override
  String toString() => 'Project($id, $title)';
}
