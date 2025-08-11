import 'dart:async';

import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

class UserDataSource extends RemoteDataSource {
  UserDataSource(Client client) : super(client);

  Future<UserTokenPairDto> login(String username, password,
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
      return Future.value(UserTokenPairDto(null, null,
          error: response != null ? response.body["code"] : 0,
          errorString:
              response != null ? response.body["message"] : "Login error"));
    client.configure(token: token);
    return UserDataSource(client)
        .getCurrentUser()
        .then((user) => UserTokenPairDto(user, token));
  }

  Future<UserTokenPairDto?> register(String username, email, password) async {
    var newUser = await client.post('/register', body: {
      'username': username,
      'email': email,
      'password': password
    }).then((resp) => resp?.body['username']);
    return login(newUser, password);
  }

  Future<UserDto> getCurrentUser() {
    return client.get('/user').then((map) => UserDto.fromJson(map?.body));
  }

  Future<UserSettingsDto?> setCurrentUserSettings(
      UserSettingsDto userSettings) async {
    return client
        .post('/user/settings/general', body: userSettings.toJson())
        .then((response) {
      if (response == null) return null;
      return userSettings;
    });
  }

  Future<String?> getToken() {
    return client.post('/user/token').then((value) => value?.body["token"]);
  }
}
