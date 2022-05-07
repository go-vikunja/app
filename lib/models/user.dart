import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/global.dart';

class User {
  final int id;
  final String email, username;

  User(this.id, this.email, this.username);
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json.containsKey('email') ? json['email'] : '',
        username = json['username'];

  toJSON() => {"id": this.id, "email": this.email, "username": this.username};

  String avatarUrl(BuildContext context) {
    return VikunjaGlobal.of(context).client.base + "/avatar/${this.username}";
  }
}

class UserTokenPair {
  final User user;
  final String token;
  UserTokenPair(this.user, this.token);
}

class BaseTokenPair {
  final String base;
  final String token;
  BaseTokenPair(this.base, this.token);
}
