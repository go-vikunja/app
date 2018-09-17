import 'dart:async';

import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/api/service.dart';
import 'package:fluttering_vikunja/models/user.dart';
import 'package:fluttering_vikunja/service/services.dart';

class UserAPIService extends APIService implements UserService {
  UserAPIService(Client client) : super(client);

  @override
  Future<UserTokenPair> login(String username, password) async {
    var token = await client.post('/login', body: {
      'username': username,
      'password': password
    }).then((map) => map['token']);
    return UserAPIService(Client(token, client.base))
        .getCurrentUser()
        .then((user) => UserTokenPair(user, token));
  }

  @override
  Future<User> getCurrentUser() {
    return client.get('/user').then((map) => User.fromJson(map));
  }
}
