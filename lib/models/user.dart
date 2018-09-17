import 'package:meta/meta.dart';

class User {
  final int id;
  final String email, username;

  User(this.id, this.email, this.username);
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        username = json['username'];

  toJSON() => {"id": this.id, "email": this.email, "username": this.username};
}

class UserTokenPair {
  final User user;
  final String token;
  UserTokenPair(this.user, this.token);
}
