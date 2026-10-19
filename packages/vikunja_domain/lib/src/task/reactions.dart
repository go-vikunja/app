import 'package:vikunja_domain/src/account/user.dart';

/// Who reacted with which emoji (or short text, at most 20 characters), in
/// the server's key order. Empty when nobody reacted.
typedef Reactions = Map<String, List<User>>;
