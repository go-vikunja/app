import 'dart:async';

import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/models/user.dart';
import 'package:fluttering_vikunja/service/services.dart';

class UserAPIService implements UserService {
  final Client _client;

  UserAPIService(this._client);

  @override
  Future<UserTokenPair> login(String username, password) async {
    var token = await _client.post('/login', body: {
      'username': username,
      'password': password
    }).then((map) => map['token']);
    return UserAPIService(Client(token, _client.base))
        .getCurrentUser()
        .then((user) => UserTokenPair(user, token));
  }

  @override
  Future<User> getCurrentUser() {
    return _client.get('/user').then((map) => User.fromJson(map));
  }
}
