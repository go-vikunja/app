String displayHost(Uri uri) {
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return uri.hasPort ? '$host:${uri.port}' : host;
}

String? displaySubPath(Uri uri) {
  final path = uri.path;
  return path.isEmpty || path == '/' ? null : path;
}
