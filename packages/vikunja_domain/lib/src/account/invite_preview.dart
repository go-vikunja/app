import 'package:meta/meta.dart';

@immutable
final class InviteTeam {
  const new({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is InviteTeam && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'InviteTeam($id)';
}

/// What an admin's registration invite gives, as the server checks it
/// before anyone registers: a name and the teams the new account joins.
@immutable
final class InvitePreview {
  new({
    required this.name,
    List<InviteTeam> teams = const [],
    this.skipsEmailConfirmation = false,
  }) : teams = List.unmodifiable(teams);

  final String name;
  final List<InviteTeam> teams;

  /// The account works right after registering, without confirming the
  /// email address first.
  final bool skipsEmailConfirmation;

  @override
  bool operator ==(Object other) =>
      other is InvitePreview &&
      other.name == name &&
      _sameTeams(other.teams, teams) &&
      other.skipsEmailConfirmation == skipsEmailConfirmation;

  @override
  int get hashCode =>
      Object.hash(name, Object.hashAll(teams), skipsEmailConfirmation);

  @override
  String toString() =>
      'InvitePreview(teams: ${teams.length}, '
      'skipsEmailConfirmation: $skipsEmailConfirmation)';
}

bool _sameTeams(List<InviteTeam> a, List<InviteTeam> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
