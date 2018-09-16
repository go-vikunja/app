import 'package:flutter/material.dart';

import 'package:crypto/crypto.dart';

class GravatarImageProvider extends NetworkImage {
  GravatarImageProvider(String email)
      : super("https://secure.gravatar.com/avatar/" +
            md5.convert(email.trim().toLowerCase().codeUnits).toString());
}
