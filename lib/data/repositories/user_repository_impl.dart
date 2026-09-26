import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/offline/offline_controller.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/local/offline_database.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';

class UserRepositoryImpl extends UserRepository {
  final UserDataSource _dataSource;
  final OfflineDatabase? _offline;
  final bool isOffline;

  UserRepositoryImpl(
    this._dataSource, {
    OfflineDatabase? offline,
    this.isOffline = false,
  }) : _offline = offline;

  @override
  Future<Response<User>> getCurrentUser() async {
    if (isOffline && _offline != null) {
      final cached = await _offline.loadUser();
      if (cached != null) return offlineSuccess<User>(cached);
      return ExceptionResponse<User>(
        StateError('User not cached'),
        StackTrace.current,
      );
    }

    final response = (await _dataSource.getCurrentUser()).toDomain<User>();
    if (response.isSuccessful) {
      await _offline?.saveUser(response.toSuccess().body);
    }
    return response;
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
