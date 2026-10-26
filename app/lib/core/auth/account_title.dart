import 'package:vikunja_domain/vikunja_domain.dart';

/// The name an account goes by: a guest's share name, else its project's
/// title as its sync last read it; a user's display name.
String accountTitle(Account account) => switch (account) {
  Account(isLinkShare: true, shareName: final name?) when name.trim() != '' =>
    name.trim(),
  _ => account.displayName,
};
