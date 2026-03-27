import 'dart:async';

import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

class UserDataSource extends RemoteDataSource {
  UserDataSource(super.client);

  Future<Response<UserDto>> getCurrentUser() {
    return client.get(
      url: '/user',
      mapper: (body) {
        return UserDto.fromJson(body);
      },
    );
  }

  Future<Response<UserSettingsDto>> setCurrentUserSettings(
    UserSettingsDto userSettings,
  ) async {
    return client.post(
      url: '/user/settings/general',
      mapper: (body) {
        return userSettings;
      },
      body: userSettings.toJson(),
    );
  }
}
