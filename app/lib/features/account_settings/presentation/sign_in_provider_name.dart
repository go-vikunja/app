/// How the server's `auth_provider` of an OIDC or LDAP account reads in a
/// sentence: the OIDC provider's configured name as it is.
String signInProviderName(String authProvider) => switch (authProvider) {
  '' => 'SSO',
  'ldap' => 'LDAP',
  final name => name,
};
