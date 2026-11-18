import 'package:flutter/foundation.dart';
import 'package:vikunja_api/vikunja_api.dart';
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

  /// The web's address of a task, at the comment [commentId] when given:
  /// on the frontend when it is http(s), never an http one for an https
  /// server, else on the server root.
  Uri taskLink(int taskId, {int? commentId}) {
    final link = webFrontendBase(
      serverRoot: serverRoot,
      frontendUrl: frontendUrl,
    ).resolve('tasks/$taskId');
    return commentId == null
        ? link
        : link.replace(fragment: 'comment-$commentId');
  }

  /// The task a pasted [text] links to: an absolute http(s) address of a
  /// task on the server or the frontend, its query and fragment ignored.
  /// Null for anything else, a relative or schemeless path too.
  int? pastedTaskLinkId(String text) {
    final trimmed = text.trim();
    if (!isWebLink(Uri.tryParse(trimmed))) return null;
    return parseTaskIdFromUrl(trimmed, bases: taskLinkBases);
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
  final uri = _resolved(stripped, bases);
  if (uri == null) return null;
  if (isSystemLink(uri)) return ExternalLinkTarget(uri);
  final resolvedTaskId = parseTaskIdFromUrl(
    uri.toString(),
    bases: bases.taskLinkBases,
  );
  if (resolvedTaskId != null) return TaskLinkTarget(resolvedTaskId);
  return ExternalLinkTarget(uri);
}

/// The full address [href] stands for, resolved as [linkTargetOf] does,
/// for showing before it opens; null when it opens nothing.
Uri? linkAddressOf(String href, AccountLinkBases bases) {
  final stripped = href.replaceAll(_ignoredInHref, '');
  return stripped.isEmpty ? null : _resolved(stripped, bases);
}

Uri? _resolved(String href, AccountLinkBases bases) {
  final parsed = Uri.tryParse(href);
  if (parsed == null) return null;
  final uri = parsed.hasScheme ? parsed : bases.relativeBase.resolveUri(parsed);
  return isSystemLink(uri) || isWebLink(uri) ? uri : null;
}

/// The host [address] opens, in punycode and lower case; null for a link
/// without one, such as `mailto:`.
String? linkHostOf(Uri address) {
  if (address.host.isEmpty) return null;
  return withAsciiHost(address).host.toLowerCase();
}

final _webAddressText = RegExp(r'^(https?://|www\.)', caseSensitive: false);
final _whitespace = RegExp(r'\s+');
final _formatCharacters = RegExp(r'\p{Cf}', unicode: true);
final _bidiControls = RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');

/// Whether a link whose text is [text] should be looked at before it opens
/// [address]: the text reads like a web address (with http(s):// or www.)
/// on another host once invisible format characters are left out, or user
/// info in either puts a host of its own before the real one, as in
/// `https://vikunja.example.com@evil.example/`. Hosts are compared in
/// punycode, ignoring case, a trailing dot and a leading `www.`. A bidi
/// control in the text always counts: it can make other characters show
/// as an address.
bool linkTextMisleads(String text, Uri address) {
  if (address.userInfo.isNotEmpty || _bidiControls.hasMatch(text)) return true;
  final word = text
      .replaceAll(_formatCharacters, '')
      .trim()
      .split(_whitespace)
      .first;
  if (!_webAddressText.hasMatch(word)) return false;
  final named = Uri.tryParse(
    word.toLowerCase().startsWith('www.') ? 'https://$word' : word,
  );
  if (named == null || named.host.isEmpty || named.userInfo.isNotEmpty) {
    return true;
  }
  return _comparable(named) != _comparable(address);
}

String? _comparable(Uri uri) {
  var host = linkHostOf(uri);
  if (host == null) return null;
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);
  return host.startsWith('www.') ? host.substring(4) : host;
}
