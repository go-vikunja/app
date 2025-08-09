import 'dart:async';

import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/models/user.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';

class UserRepositoryImpl extends UserRepository {
  UserDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<UserTokenPair> login(String username, password,
      {bool rememberMe = false, String? totp}) async {
    return (await _dataSource.login(username, password)).toDomain();
  }

  @override
  Future<UserTokenPair?> register(String username, email, password) async {
    return (await _dataSource.register(username, email, password))?.toDomain();
  }

  @override
  Future<User> getCurrentUser() async {
    return (await _dataSource.getCurrentUser()).toDomain();
  }

  @override
  Future<UserSettings?> setCurrentUserSettings(
      UserSettings userSettings) async {
    return (await _dataSource
            .setCurrentUserSettings(UserSettingsDto.fromDomain(userSettings)))
        ?.toDomain();
  }

  @override
  Future<String?> getToken() {
    return _dataSource.getToken();
  }
}
