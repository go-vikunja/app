import 'package:meta/meta.dart';

/// The fields of one project edit. Every null field is left as it is on the
/// server; the adapters send only what is set (v2 merge-patch) or overlay it
/// on a fresh read (v1 full replace).
@immutable
final class ProjectChanges {
  const new({
    this.title,
    this.description,
    this.identifier,
    this.hexColor,
    this.parentProjectId,
    this.isFavorite,
    this.isArchived,
    this.position,
  });

  final String? title;

  /// HTML as the web's editor writes it.
  final String? description;

  /// Up to 10 characters, stored upper-case and unique on the whole
  /// instance; empty removes it. Task identifiers follow at once.
  final String? identifier;

  /// Six hex digits without `#`; empty removes the colour.
  final String? hexColor;

  /// 0 for the top level; the position stays.
  final int? parentProjectId;

  /// Per user.
  final bool? isFavorite;

  /// Cascades to every descendant on the server, both ways.
  final bool? isArchived;

  /// 0.1 or more: a project stored below it after an update makes the server
  /// renumber all its siblings, at the top level those of every user.
  final double? position;

  bool get isEmpty =>
      title == null &&
      description == null &&
      identifier == null &&
      hexColor == null &&
      parentProjectId == null &&
      isFavorite == null &&
      isArchived == null &&
      position == null;

  @override
  bool operator ==(Object other) =>
      other is ProjectChanges &&
      other.title == title &&
      other.description == description &&
      other.identifier == identifier &&
      other.hexColor == hexColor &&
      other.parentProjectId == parentProjectId &&
      other.isFavorite == isFavorite &&
      other.isArchived == isArchived &&
      other.position == position;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    identifier,
    hexColor,
    parentProjectId,
    isFavorite,
    isArchived,
    position,
  );

  /// Names the fields set, without user text such as the title.
  @override
  String toString() {
    final fields = [
      if (title != null) 'title',
      if (description != null) 'description',
      if (identifier != null) 'identifier',
      if (hexColor != null) 'hexColor',
      if (parentProjectId != null) 'parentProjectId: $parentProjectId',
      if (isFavorite != null) 'isFavorite: $isFavorite',
      if (isArchived != null) 'isArchived: $isArchived',
      if (position != null) 'position: $position',
    ];
    return 'ProjectChanges(${fields.join(', ')})';
  }
}
