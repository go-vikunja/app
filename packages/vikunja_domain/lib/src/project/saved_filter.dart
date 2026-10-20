import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/project.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

/// A saved filter as `GET /filters/{id}` answers it. The project list
/// names it as the pseudo project [pseudoProjectId], without [filter].
@immutable
final class SavedFilter {
  const new({
    required this.id,
    required this.title,
    required this.filter,
    this.description = '',
    this.isFavorite = false,
    this.timezone = '',
    this.created,
    this.updated,
  });

  final int id;
  final String title;
  final String description;

  /// The filter text, include-nulls flag, search and sort. The server
  /// never applies the stored search to the filter's tasks.
  final ViewFilter filter;
  final bool isFavorite;

  /// The zone relative dates in [filter] are rounded in; empty for the
  /// owner's timezone setting. 2.7.0 cannot store one (v1 drops it, v2
  /// refuses it), so it is only read.
  final String timezone;
  final DateTime? created;
  final DateTime? updated;

  int get pseudoProjectId => pseudoProjectIdOf(id);

  /// Saved filter `n` is listed as project `-n - 1`.
  static int pseudoProjectIdOf(int filterId) => -filterId - 1;

  /// The saved filter's id for its pseudo project id; null for an id that
  /// is not one ([Project.favoritesId] and up).
  static int? idOfPseudoProject(int projectId) =>
      projectId < Project.favoritesId ? -projectId - 1 : null;

  @override
  bool operator ==(Object other) =>
      other is SavedFilter &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.filter == filter &&
      other.isFavorite == isFavorite &&
      other.timezone == timezone &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    filter,
    isFavorite,
    timezone,
    updated,
  );

  @override
  String toString() => 'SavedFilter($id)';
}

/// What the app sends to create a saved filter or to replace one: every
/// field is sent.
@immutable
final class SavedFilterDraft {
  const new({
    required this.title,
    required this.filter,
    this.description = '',
    this.isFavorite = false,
  });

  /// 1 to 250 characters.
  final String title;

  /// Plain text; the server stores it as it is sent.
  final String description;

  /// The server refuses a filter that has neither filter text, search,
  /// sort nor include-nulls set (code 2002), and a filter it cannot parse
  /// (4016, 4019, 4024).
  final ViewFilter filter;
  final bool isFavorite;

  @override
  bool operator ==(Object other) =>
      other is SavedFilterDraft &&
      other.title == title &&
      other.description == description &&
      other.filter == filter &&
      other.isFavorite == isFavorite;

  @override
  int get hashCode => Object.hash(title, description, filter, isFavorite);

  /// Without the title, the description and the filter, which are user
  /// text.
  @override
  String toString() => 'SavedFilterDraft(favorite: $isFavorite)';
}
