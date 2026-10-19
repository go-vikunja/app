import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/deep_link_source.dart';

/// Whether [uri] is on the app's own scheme, which the router never routes.
bool isAppSchemeUri(Uri uri) => uri.scheme.toLowerCase() == oauthCallbackScheme;

/// The [DeepLinkSource] of the running app: the router hands every URI of
/// the app's scheme the platform pushes to [accept], and the start link is
/// read once from the platform's default route (Android passes the launch
/// URI as the initial route). Only `task` links go on; a link that arrives
/// before anyone listens waits for the first listener.
final class DeepLinkRelay implements DeepLinkSource {
  new({String Function()? defaultRouteName})
    : _defaultRouteName =
          defaultRouteName ??
          // The binding's dispatcher, which tests can give a start link.
          (() => WidgetsBinding.instance.platformDispatcher.defaultRouteName);

  final String Function() _defaultRouteName;
  final _pending = <Uri>[];
  late final _links = StreamController<Uri>.broadcast(onListen: _flush);
  var _initialRead = false;

  @override
  Stream<Uri> get links => _links.stream;

  @override
  Future<Uri?> initialLink() async {
    if (_initialRead) return null;
    _initialRead = true;
    final uri = Uri.tryParse(_defaultRouteName());
    if (uri == null || !isAppSchemeUri(uri) || !_isTaskLink(uri)) return null;
    return uri;
  }

  /// True when [uri] is on the app's scheme, so the router must block it;
  /// a `task` link is passed on, anything else (an `oauth` callback that
  /// arrived after its sign-in ended) is dropped.
  bool accept(Uri uri) {
    if (!isAppSchemeUri(uri)) return false;
    if (_isTaskLink(uri)) {
      if (_links.hasListener) {
        _links.add(uri);
      } else {
        _pending.add(uri);
      }
    }
    return true;
  }

  Future<void> dispose() => _links.close();

  static bool _isTaskLink(Uri uri) => uri.host.toLowerCase() == 'task';

  void _flush() {
    final pending = List.of(_pending);
    _pending.clear();
    pending.forEach(_links.add);
  }
}
