import 'package:vikunja_domain/vikunja_domain.dart';

/// Who cannot be added as a person: the user, the project's owner (the
/// server refuses both as already shared) and everyone shared already.
Set<int> peopleNotToOffer({
  required List<ProjectUserShare> shares,
  required int? currentUserId,
  required int? ownerId,
}) => {?currentUserId, ?ownerId, for (final share in shares) share.user.id};

/// [teams] whose name contains the trimmed [query], ignoring case.
List<Team> filterTeams(List<Team> teams, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return teams;
  return [
    for (final team in teams)
      if (team.name.toLowerCase().contains(needle)) team,
  ];
}
