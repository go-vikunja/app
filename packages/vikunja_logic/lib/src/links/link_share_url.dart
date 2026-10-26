/// Where the server's web frontend is: the `frontend_url` of `/info` when
/// it is http(s), else the server root; never an http frontend for an https
/// server (a stale `service.publicurl` behind a TLS proxy). As a directory.
Uri webFrontendBase({required Uri serverRoot, Uri? frontendUrl}) {
  final usable =
      frontendUrl != null &&
      (frontendUrl.isScheme('https') ||
          frontendUrl.isScheme('http') && !serverRoot.isScheme('https')) &&
      frontendUrl.host.isNotEmpty;
  return _directory(usable ? frontendUrl : serverRoot);
}

/// The web's address of a link share: `{base}share/{hash}/auth`, with
/// `?view={viewId}` to open that view. [base] is the web frontend, see
/// [webFrontendBase]. The URL carries the share's secret: never log it.
Uri linkShareUrl({required Uri base, required String hash, int? viewId}) =>
    _directory(base).replace(
      path: '${_directory(base).path}share/${Uri.encodeComponent(hash)}/auth',
      queryParameters: viewId == null ? null : {'view': '$viewId'},
    );

Uri _directory(Uri base) {
  final path = base.path.endsWith('/') ? base.path : '${base.path}/';
  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
  );
}
