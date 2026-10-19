import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

/// What a tap on a link in rich text opens.
@immutable
sealed class LinkTarget {
  const new();
}

/// A task of the account the text belongs to, opened in the app.
final class TaskLinkTarget extends LinkTarget {
  const new(this.taskId);

  final int taskId;

  @override
  bool operator ==(Object other) =>
      other is TaskLinkTarget && other.taskId == taskId;

  @override
  int get hashCode => taskId.hashCode;

  @override
  String toString() => 'TaskLinkTarget($taskId)';
}

/// An http(s) page, opened in the browser, or a link of one of
/// [systemLinkSchemes], handed to the app that handles it.
final class ExternalLinkTarget extends LinkTarget {
  const new(this.uri);

  final Uri uri;

  @override
  bool operator ==(Object other) =>
      other is ExternalLinkTarget && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'ExternalLinkTarget($uri)';
}

/// Where an account's own links point: its server and the web frontend
/// `/info` names, both with their path prefix.
@immutable
final class AccountLinkBases {
  const new({required this.serverRoot, this.frontendUrl});

  /// [ServerInfo.frontendUrl] counts only as http(s).
  factory of(ServerConnection connection) => AccountLinkBases(
    serverRoot: connection.rootUri,
    frontendUrl: isWebLink(connection.info.frontendUrl)
        ? connection.info.frontendUrl
        : null,
  );

  final Uri serverRoot;
  final Uri? frontendUrl;

  List<Uri> get taskLinkBases => [serverRoot, ?frontendUrl];

  /// What a relative link is resolved against: the frontend, where the web
  /// shows it, else the server; as a directory, like the web's base URL.
  Uri get relativeBase {
    final base = frontendUrl ?? serverRoot;
    return base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
  }

  @override
  bool operator ==(Object other) =>
      other is AccountLinkBases &&
      other.serverRoot == serverRoot &&
      other.frontendUrl == frontendUrl;

  @override
  int get hashCode => Object.hash(serverRoot, frontendUrl);
}

// The characters the web's `isAllowedUri` strips before it looks at a href.
final _ignoredInHref = RegExp(
  r'[\u0000-\u0020\u00A0\u1680\u180E\u2000-\u2029\u205F\u3000]',
);

/// What [href] (a link the rich text parser kept) opens: a task URL of
/// the account as the task; an http(s) or other allowed link outside; a
/// relative or schemeless one resolved against [AccountLinkBases.relativeBase]
/// first. Null for anything else, which is never opened.
LinkTarget? linkTargetOf(String href, AccountLinkBases bases) {
  final stripped = href.replaceAll(_ignoredInHref, '');
  if (stripped.isEmpty) return null;
  final taskId = parseTaskIdFromUrl(stripped, bases: bases.taskLinkBases);
  if (taskId != null) return TaskLinkTarget(taskId);
  final parsed = Uri.tryParse(stripped);
  if (parsed == null) return null;
  final uri = parsed.hasScheme ? parsed : bases.relativeBase.resolveUri(parsed);
  if (isSystemLink(uri)) return ExternalLinkTarget(uri);
  if (!isWebLink(uri)) return null;
  final resolvedTaskId = parseTaskIdFromUrl(
    uri.toString(),
    bases: bases.taskLinkBases,
  );
  if (resolvedTaskId != null) return TaskLinkTarget(resolvedTaskId);
  return ExternalLinkTarget(uri);
}
