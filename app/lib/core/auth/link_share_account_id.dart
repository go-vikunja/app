import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The same share on the same server always maps to the same id, so opening
/// a link again replaces the guest instead of adding a second one; the
/// `share` part keeps it apart from every user's id (`accountIdFor`).
String linkShareAccountIdFor(Uri serverRoot, int shareId) => sha256
    .convert(utf8.encode('$serverRoot|share|$shareId'))
    .toString()
    .substring(0, 32);
