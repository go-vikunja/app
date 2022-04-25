import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';

class UserAPIService extends APIService implements UserService {
  UserAPIService(Client client) : super(client);

  @override
  Future<UserTokenPair> login(String username, password, {bool rememberMe = false}) async {
    var token = await client.post('/login', body: {
      'username': username,
      'password': password,
      'long_token': rememberMe
    }).then((response) => response.body['token']);
    return UserAPIService(Client(token, client.base))
        .getCurrentUser()
        .then((user) => UserTokenPair(user, token));
  }

  @override
  Future<UserTokenPair> register(String username, email, password) async {
    var newUser = await client.post('/register', body: {
      'username': username,
      'email': email,
      'password': password
    }).then((resp) => resp.body['username']);
    return login(newUser, password);
  }

  @override
  Future<User> getCurrentUser() {
    return client.get('/user').then((map) => User.fromJson(map.body));
  }
}
