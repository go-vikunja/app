import 'dart:ui' show Rect;

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

part 'link_share_actions.g.dart';

final _log = Logger('LinkShareActions');

/// Hands a link or a text to another app through the system's share
/// sheet. A link share's URL carries its secret: never log it, nor the
/// text. An `origin` anchors the share sheet on an iPad.
abstract interface class LinkShareActions {
  /// False when the system has no share sheet; a dismissed sheet is true.
  Future<bool> shareLink(Uri url, {String? subject, Rect? origin});

  /// Like [shareLink].
  Future<bool> shareText(String text, {String? subject, Rect? origin});
}

/// Leaving the app for the share sheet does not lock it.
final class PlatformLinkShareActions implements LinkShareActions {
  new({
    Future<ShareResult> Function(ShareParams params)? share,
    this._excursions,
  }) : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams params) _share;
  final AppExcursions? _excursions;

  @override
  Future<bool> shareLink(Uri url, {String? subject, Rect? origin}) async {
    Future<ShareResult> share() => _share(
      ShareParams(uri: url, subject: subject, sharePositionOrigin: origin),
    );
    final result = await (_excursions?.roundTrip(share) ?? share());
    _log.fine('Shared a link: ${result.status.name}');
    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) async {
    Future<ShareResult> share() => _share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
    final result = await (_excursions?.roundTrip(share) ?? share());
    _log.fine('Shared a text: ${result.status.name}');
    return result.status != ShareResultStatus.unavailable;
  }
}

@Riverpod(keepAlive: true)
LinkShareActions linkShareActions(Ref ref) =>
    PlatformLinkShareActions(excursions: ref.watch(appExcursionsProvider));
