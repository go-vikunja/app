import 'package:vikunja_domain/vikunja_domain.dart';

enum NameProblem {
  /// Empty or only whitespace: the server would store it (v1) or refuse it.
  blank,

  /// More code points than the server takes.
  tooLong,
}

/// Null when the server takes [title] for a label.
NameProblem? labelTitleProblem(String title) =>
    _nameProblem(title, Label.maxTitleLength);

/// Null when the server takes [name] for a team.
NameProblem? teamNameProblem(String name) =>
    _nameProblem(name, Team.maxNameLength);

NameProblem? _nameProblem(String name, int maxLength) {
  if (name.trim().isEmpty) return NameProblem.blank;
  if (name.runes.length > maxLength) return NameProblem.tooLong;
  return null;
}
