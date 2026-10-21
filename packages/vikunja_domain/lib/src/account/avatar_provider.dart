/// Where the server takes a user's avatar from.
enum AvatarProvider {
  defaultAvatar('default'),
  initials('initials'),
  gravatar('gravatar'),
  marble('marble'),
  upload('upload'),

  /// Set by an LDAP sign-in from the directory's photo.
  ldap('ldap'),

  /// Set by an OIDC sign-in from the provider's picture.
  openid('openid');

  new(this.wireName);

  final String wireName;

  /// What a user can pick, in the web's order. `upload` shows the uploaded
  /// image, and the server fails every avatar request while none exists.
  static const List<AvatarProvider> choices = [
    defaultAvatar,
    initials,
    gravatar,
    marble,
    upload,
  ];

  bool get isFromSignIn => this == ldap || this == openid;

  /// The server renders an empty provider like `default`.
  static AvatarProvider? fromWire(Object? value) => value == ''
      ? defaultAvatar
      : values.where((provider) => provider.wireName == value).firstOrNull;
}
