/// Builds Vikunja filter expressions for text search.
///
/// The tasks API cannot combine the `s` search parameter with `filter`,
/// so overview queries that already filter (e.g. `done = false`) must use
/// `like` instead. Values are quoted and escaped for the filter parser.
String? searchLikeClause(
  String query, {
  List<String> fields = const ['title', 'description'],
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty || fields.isEmpty) {
    return null;
  }

  final escaped = _escapeFilterValue(trimmed);
  final clauses = fields.map((field) => "$field like '%$escaped%'");

  if (fields.length == 1) {
    return clauses.first;
  }

  return '(${clauses.join(' || ')})';
}

String combineFilterClauses(Iterable<String> clauses) {
  return clauses.where((clause) => clause.trim().isNotEmpty).join(' && ');
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
