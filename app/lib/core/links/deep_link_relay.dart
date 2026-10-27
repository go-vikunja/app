import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/deep_link_source.dart';

/// Whether [uri] is on the app's own scheme, which the router never routes.
bool isAppSchemeUri(Uri uri) => uri.scheme.toLowerCase() == oauthCallbackScheme;

/// The [DeepLinkSource] of the running app: the router hands every URI of
/// the app's scheme the platform pushes to [accept], and the start link is
/// read once from the platform's default route (Android passes the launch
/// URI as the initial route). Only `task` links go on here and `widget`
/// links through [widgetLinks]; a link that arrives before anyone listens
/// waits for the first listener.
final class DeepLinkRelay implements DeepLinkSource {
  new({String Function()? defaultRouteName})
    : _defaultRouteName =
          defaultRouteName ??
          // The binding's dispatcher, which tests can give a start link.
          (() => WidgetsBinding.instance.platformDispatcher.defaultRouteName);

  final String Function() _defaultRouteName;
  late final _tasks = _HostLinks('task', _startLink);
  late final _widgets = _HostLinks('widget', _startLink);

  /// The links of the app's home-screen widgets (`<scheme>://widget/…`).
  DeepLinkSource get widgetLinks => _widgets;

  @override
  Stream<Uri> get links => _tasks.links;

  @override
  Future<Uri?> initialLink() => _tasks.initialLink();

  /// True when [uri] is on the app's scheme, so the router must block it;
  /// a `task` or `widget` link is passed on, anything else (an `oauth`
  /// callback that arrived after its sign-in ended) is dropped.
  bool accept(Uri uri) {
    if (!isAppSchemeUri(uri)) return false;
    for (final hostLinks in [_tasks, _widgets]) {
      if (hostLinks.takes(uri)) hostLinks.add(uri);
    }
    return true;
  }

  Future<void> dispose() => Future.wait([_tasks.close(), _widgets.close()]);

  Uri? _startLink() {
    final uri = Uri.tryParse(_defaultRouteName());
    return uri != null && isAppSchemeUri(uri) ? uri : null;
  }
}

final class _HostLinks implements DeepLinkSource {
  new(this._host, this._startLink);

  final String _host;
  final Uri? Function() _startLink;
  final _pending = <Uri>[];
  late final _links = StreamController<Uri>.broadcast(onListen: _flush);
  var _initialRead = false;

  @override
  Stream<Uri> get links => _links.stream;

  @override
  Future<Uri?> initialLink() async {
    if (_initialRead) return null;
    _initialRead = true;
    final uri = _startLink();
    return uri != null && takes(uri) ? uri : null;
  }

  bool takes(Uri uri) => uri.host.toLowerCase() == _host;

  void add(Uri uri) {
    if (_links.hasListener) {
      _links.add(uri);
    } else {
      _pending.add(uri);
    }
  }

  Future<void> close() => _links.close();

  void _flush() {
    final pending = List.of(_pending);
    _pending.clear();
    pending.forEach(_links.add);
  }
}
