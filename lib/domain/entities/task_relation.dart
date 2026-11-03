enum RelationKind {
  copiedto,
  copiedfrom,
  follows,
  precedes,
  blocked,
  blocking,
  duplicates,
  duplicateof,
  related,
  parenttask,
  subtask;

  String get apiValue => name;

  static const List<RelationKind> selectable = [
    copiedto,
    copiedfrom,
    follows,
    precedes,
    blocked,
    blocking,
    duplicates,
    duplicateof,
    related,
    parenttask,
    subtask,
  ];

  static RelationKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}
