import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test("the server's wire names", () {
    expect(
      [for (final provider in AvatarProvider.values) provider.wireName],
      ['default', 'initials', 'gravatar', 'marble', 'upload', 'ldap', 'openid'],
    );
    for (final provider in AvatarProvider.values) {
      expect(AvatarProvider.fromWire(provider.wireName), provider);
    }
  });

  test('an empty provider renders like default; anything else is unknown, '
      'case-sensitive like the server', () {
    expect(AvatarProvider.fromWire(''), AvatarProvider.defaultAvatar);
    for (final other in [null, 'Initials', 'robohash', 1, true]) {
      expect(AvatarProvider.fromWire(other), isNull, reason: '$other');
    }
  });

  test("the choices are the web's, in its order, without the sign-in "
      'providers', () {
    expect(AvatarProvider.choices, [
      AvatarProvider.defaultAvatar,
      AvatarProvider.initials,
      AvatarProvider.gravatar,
      AvatarProvider.marble,
      AvatarProvider.upload,
    ]);
    expect(
      [
        for (final provider in AvatarProvider.values)
          if (provider.isFromSignIn) provider,
      ],
      [AvatarProvider.ldap, AvatarProvider.openid],
    );
  });
}
