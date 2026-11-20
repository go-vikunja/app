/// The [candidates] a typed project identifier [wanted] names: those whose
/// identifier is exactly [wanted], else those equal to it ignoring case
/// (both sides lower-cased, as Go's upper-casing keeps `ß`); never one
/// without an identifier. Vikunja 2.4 and later store identifiers
/// upper-cased and unique ignoring case, so at most one matches there.
/// 2.3 keeps them as typed and unique only as typed: `ab` and `AB` can both
/// exist, and `Ab` then names both. A caller that needs one project takes a
/// single match only.
List<T> namedByIdentifier<T>(
  String wanted,
  Iterable<T> candidates, {
  required String Function(T candidate) identifierOf,
}) {
  final exact = [
    for (final candidate in candidates)
      if (identifierOf(candidate) case final identifier
          when identifier.isNotEmpty && identifier == wanted)
        candidate,
  ];
  if (exact.isNotEmpty) return exact;
  final lower = wanted.toLowerCase();
  return [
    for (final candidate in candidates)
      if (identifierOf(candidate) case final identifier
          when identifier.isNotEmpty && identifier.toLowerCase() == lower)
        candidate,
  ];
}
