import 'dart:async';

import 'package:vikunja_app/domain/entities/user.dart';

abstract class UserRepository {
  Future<UserToken> login(
    String username,
    password, {
    bool rememberMe = false,
    String? totp,
  });

  Future<UserToken?> register(String username, email, password);

  Future<User> getCurrentUser();

  Future<UserSettings?> setCurrentUserSettings(UserSettings userSettings);

  Future<String?> getToken();
}
