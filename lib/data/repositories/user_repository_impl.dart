import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';

class UserRepositoryImpl extends UserRepository {
  final UserDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<Response<User>> getCurrentUser() async {
    return (await _dataSource.getCurrentUser()).toDomain();
  }

  @override
  Future<Response<UserSettings>> setCurrentUserSettings(
    UserSettings userSettings,
  ) async {
    return (await _dataSource.setCurrentUserSettings(
      UserSettingsDto.fromDomain(userSettings),
    )).toDomain();
  }
}
