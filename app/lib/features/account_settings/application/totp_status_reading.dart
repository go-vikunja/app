import 'package:vikunja_domain/vikunja_domain.dart';

/// Servers before 2.7 answer the two-factor status with its secret even
/// while it is on, which must not cross an unencrypted connection.
bool canReadTotpStatus(ServerConnection connection) =>
    !connection.isInsecure ||
    (connection.info.version?.isAtLeast(2, 7) ?? false);
