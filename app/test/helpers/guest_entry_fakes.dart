import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';

import 'guest_fakes.dart';

/// `{base}share/{hash}/auth?view=…` with the fake hash.
String shareLink({
  String base = 'https://tasks.example.org/vikunja/',
  int? viewId,
}) =>
    '${base}share/$fakeShareHash/auth${viewId == null ? '' : '?view=$viewId'}';

/// An invite's token, as obviously fake as [fakeShareHash].
final String fakeInviteToken = 'i' * 64;

String inviteLink({String base = 'https://tasks.example.org/vikunja/'}) =>
    '${base}register#invite-link=$fakeInviteToken';

/// `POST /invite-links/check`: answered by [onCheck], recording the tokens.
final class FakeInviteLinksPort implements InviteLinksPort {
  Future<InvitePreview> Function(String token)? onCheck;
  final List<String> checkedTokens = [];
  final List<ServerConnection> connections = [];

  @override
  Future<InvitePreview> check(String token) {
    checkedTokens.add(token);
    final handler = onCheck;
    if (handler == null) throw StateError('no invite check expected');
    return handler(token);
  }
}

/// The invite checks of [invites], and the shared project's title from
/// [projectTitle] instead of a request; the guest sign-in itself runs on
/// the fakes of `AuthFakes` and the connector the app's overrides hold.
List<Override> guestEntryOverrides({
  FakeInviteLinksPort? invites,
  String? projectTitle = 'Garden',
}) => [
  inviteLinksPortsProvider.overrideWithValue((connection) {
    invites?.connections.add(connection);
    return invites ?? FakeInviteLinksPort();
  }),
  sharedProjectTitleProvider.overrideWithValue((_, _, _) async => projectTitle),
];
