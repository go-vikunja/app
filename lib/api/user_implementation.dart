import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';

class UserAPIService extends APIService implements UserService {
  UserAPIService(Client client) : super(client);

  @override
  Future<UserTokenPair> login(String username, password,
      {bool rememberMe = false, String? totp}) async {
    var body = {
      'long_token': rememberMe,
      'password': password,
      'username': username,
    };
    if (totp != null) {
      body['totp_passcode'] = totp;
    }
    var response = await client.post('/login', body: body);
    var token = response?.body["token"];
    if (token == null || response == null || response.error != null)
      return Future.value(UserTokenPair(null, null,
          error: response != null ? response.body["code"] : 0,
          errorString:
              response != null ? response.body["message"] : "Login error"));
    client.configure(token: token);
    return UserAPIService(client)
        .getCurrentUser()
        .then((user) => UserTokenPair(user, token));
  }

  @override
  Future<UserTokenPair?> register(String username, email, password) async {
    var newUser = await client.post('/register', body: {
      'username': username,
      'email': email,
      'password': password
    }).then((resp) => resp?.body['username']);
    return login(newUser, password);
  }

  @override
  Future<User> getCurrentUser() {
    return client.get('/user').then((map) => User.fromJson(map?.body));
  }

  @override
  Future<UserSettings?> setCurrentUserSettings(
      UserSettings userSettings) async {
    return client
        .post('/user/settings/general', body: userSettings.toJson())
        .then((response) {
      if (response == null) return null;
      return userSettings;
    });
  }

  @override
  Future<String?> getToken() {
    return client.post('/user/token').then((value) => value?.body["token"]);
  }
}
