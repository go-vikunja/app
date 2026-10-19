import 'package:meta/meta.dart';

@immutable
final class AttachmentRef {
  const new({required this.taskId, required this.attachmentId});

  final int taskId;
  final int attachmentId;

  @override
  bool operator ==(Object other) =>
      other is AttachmentRef &&
      other.taskId == taskId &&
      other.attachmentId == attachmentId;

  @override
  int get hashCode => Object.hash(taskId, attachmentId);

  @override
  String toString() => 'AttachmentRef($taskId, $attachmentId)';
}

final _attachmentUrl = RegExp(
  r'^(.*?)(?:/api/v[12])?/tasks/(\d+)/attachments/(\d+)$',
);
final _apiSuffix = RegExp(r'/api/v[12]$');

/// The attachment an inline image points at: the web's
/// `^(.*?)(?:/api/v[12])?/tasks/(\d+)/attachments/(\d+)$` on [src], where
/// the captured prefix must be the server's own: [apiRoot] without any
/// `/api/vN` and trailing slash, compared after normalising scheme and host
/// case and default ports, and an empty prefix (a relative src) means this
/// server, as does a root-relative prefix equal to the root's sub-path.
/// Anchored at both ends: a query, a fragment or a trailing slash is a
/// plain image. A src of another host, another API version or a prefix
/// that differs is null; so are non-numeric ids and ids beyond 64 bits.
/// Leading zeros are accepted (`0012` is 12). Surrounding whitespace is
/// ignored, like a browser does for `src`.
AttachmentRef? parseAttachmentUrl(String src, {required Uri apiRoot}) {
  final match = _attachmentUrl.firstMatch(src.trim());
  if (match == null) return null;
  final taskId = int.tryParse(match[2]!);
  final attachmentId = int.tryParse(match[3]!);
  if (taskId == null || attachmentId == null) return null;
  if (!_isOwnPrefix(match[1]!, apiRoot)) return null;
  return AttachmentRef(taskId: taskId, attachmentId: attachmentId);
}

bool _isOwnPrefix(String prefix, Uri apiRoot) {
  final rootPath = _rootPath(apiRoot);
  if (prefix.isEmpty) return true;
  if (prefix.startsWith('/') && !prefix.startsWith('//')) {
    return prefix == rootPath;
  }
  final parsed = Uri.tryParse(prefix);
  if (parsed == null ||
      !parsed.hasScheme ||
      !parsed.hasAuthority ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    return false;
  }
  return parsed.scheme.toLowerCase() == apiRoot.scheme.toLowerCase() &&
      parsed.host.toLowerCase() == apiRoot.host.toLowerCase() &&
      parsed.port == apiRoot.port &&
      parsed.path == rootPath;
}

String _rootPath(Uri apiRoot) {
  var path = apiRoot.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path.replaceFirst(_apiSuffix, '');
}
