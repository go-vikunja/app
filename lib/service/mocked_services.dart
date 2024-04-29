import 'dart:async';

import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';

// Data for mocked services
var _users = {1: User(id: 1, username: 'test1')};

class MockedUserService implements UserService {
  @override
  Future<UserTokenPair> login(String username, password,
      {bool rememberMe = false, String? totp}) {
    return Future.value(UserTokenPair(_users[1]!, 'abcdefg'));
  }

  @override
  Future<UserTokenPair> register(String username, email, password) {
    return Future.value(UserTokenPair(_users[1]!, 'abcdefg'));
  }

  @override
  Future<User> getCurrentUser() {
    return Future.value(_users[1]);
  }

  @override
  Future<UserSettings> setCurrentUserSettings(UserSettings userSettings) {
    // TODO: implement setCurrentUserSettings
    throw UnimplementedError();
  }

  @override
  Future<String?> getToken() {
    // TODO: implement getToken
    throw UnimplementedError();
  }
}
