import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/global.dart';

class User {
  final int id;
  final String name, username;
  final DateTime created, updated;

  User({
    this.id = -1,
    this.name = '',
    required this.username,
    DateTime? created,
    DateTime? updated,
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json.containsKey('name') ? json['name'] : '',
        username = json['username'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']);

  toJSON() => {
        'id': id != -1 ? id : null,
        'name': name,
        'username': username,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
      };

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
