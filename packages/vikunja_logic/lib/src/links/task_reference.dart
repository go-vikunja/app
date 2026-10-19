import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/links/url_text.dart';

/// What a link or a typed text names: a task by its server id, or by its
/// project identifier and index (`PROJ-12`).
@immutable
sealed class TaskReference {
  const new();
}

final class TaskById extends TaskReference {
  const new(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is TaskById && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TaskById($id)';
}

final class TaskByIdentifier extends TaskReference {
  /// [identifier] as typed; the server upper-cases with Go's rules, which
  /// keep `ß`, so compare it case-insensitively by lower-casing both sides
  /// and send it unchanged. [index] is above 0.
  const new(this.identifier, this.index);

  final String identifier;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is TaskByIdentifier &&
      other.identifier == identifier &&
      other.index == index;

  @override
  int get hashCode => Object.hash(identifier, index);

  @override
  String toString() => 'TaskByIdentifier($identifier, $index)';
}

/// `12` is a task id; `PROJ-12` is identifier and index, split at the
/// last `-` (identifiers may contain one, and spaces, dots or digits:
/// `MY-PRJ-12`), the index without leading zeros (`PROJ-0012` is 12).
/// Surrounding whitespace is ignored. Null for anything else: `PROJ-`,
/// `-12`, `PROJ-0`, `PROJ-1x`, `#12` (no project), an id of 0, a number
/// beyond 2^53 - 1, the empty text. A bare number is always an id.
TaskReference? parseTaskReference(String text) {
  final trimmed = text.trim();
  if (_digits.hasMatch(trimmed)) {
    final id = _positiveSafeInt(trimmed);
    return id == null ? null : TaskById(id);
  }
  final dash = trimmed.lastIndexOf('-');
  if (dash <= 0) return null;
  final indexText = trimmed.substring(dash + 1);
  if (!_digits.hasMatch(indexText)) return null;
  final index = _positiveSafeInt(indexText);
  if (index == null) return null;
  return TaskByIdentifier(trimmed.substring(0, dash), index);
}

final _digits = RegExp(r'^[0-9]+$');

int? _positiveSafeInt(String digits) {
  final value = int.tryParse(digits);
  return value != null && value > 0 && value <= maxSafeInteger ? value : null;
}

/// `<scheme>://task/<reference>[?account=<id>]`: [account] is the app's
/// own account id, set only by links the app makes itself, because a task
/// id exists on every server.
@immutable
final class TaskDeepLink {
  const new(this.reference, {this.account});

  final TaskReference reference;
  final String? account;

  @override
  bool operator ==(Object other) =>
      other is TaskDeepLink &&
      other.reference == reference &&
      other.account == account;

  @override
  int get hashCode => Object.hash(reference, account);

  @override
  String toString() => 'TaskDeepLink($reference, $account)';
}

/// Null unless the scheme equals [scheme] (case-insensitive), the host is
/// `task`, there is no user info or port, and the path is exactly one
/// non-empty segment (percent-decoded) that [parseTaskReference] accepts.
/// An empty `account` counts as none; other query parameters are ignored;
/// an escape that does not decode as UTF-8 makes it null.
TaskDeepLink? parseTaskDeepLink(Uri uri, {required String scheme}) {
  if (uri.scheme.toLowerCase() != scheme.toLowerCase() ||
      uri.host.toLowerCase() != _taskHost ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final List<String> segments;
  final String? account;
  try {
    segments = uri.pathSegments;
    account = uri.queryParameters['account'];
  } on FormatException {
    // An escape that is no UTF-8.
    return null;
  }
  if (segments.length != 1 || segments.single.isEmpty) return null;
  final reference = parseTaskReference(segments.single);
  if (reference == null) return null;
  return TaskDeepLink(
    reference,
    account: account == null || account.isEmpty ? null : account,
  );
}

const _taskHost = 'task';

/// The inverse of [parseTaskDeepLink].
Uri buildTaskDeepLink(
  TaskReference reference, {
  required String scheme,
  String? account,
}) => Uri(
  scheme: scheme,
  host: _taskHost,
  pathSegments: [
    switch (reference) {
      TaskById(:final id) => '$id',
      TaskByIdentifier(:final identifier, :final index) => '$identifier-$index',
    },
  ],
  queryParameters: account == null || account.isEmpty
      ? null
      : {'account': account},
);
