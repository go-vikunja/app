import 'dart:async';

import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

class UserDataSource extends RemoteDataSource {
  UserDataSource(super.client);

  Future<Response<UserTokenDto>> login(
    String username,
    password, {
    bool rememberMe = false,
    String? totp,
  }) async {
    var body = {
      'long_token': rememberMe,
      'password': password,
      'username': username,
    };
    if (totp != null) {
      body['totp_passcode'] = totp;
    }

    var response = await client.postWithCookies(
      url: '/login',
      mapper: (body) {
        var token = body["token"];
        return UserTokenDto(token);
      },
      body: body,
    );

    if (response.isSuccessful) {
      var success = response.toSuccess();
      var refreshCookie = extractRefreshCookie(success.headers);
      if (refreshCookie != null) {
        return SuccessResponse<UserTokenDto>(
          UserTokenDto(success.body.token, refreshCookie: refreshCookie),
          success.statusCode,
          success.headers,
        );
      }
    }

    return response;
  }

  Future<Response<UserTokenDto>> register(
    String username,
    email,
    password,
  ) async {
    var registerResponse = await client.post(
      url: '/register',
      body: {'username': username, 'email': email, 'password': password},
      mapper: (body) {
        return body['username'];
      },
    );

    if (registerResponse.isSuccessful) {
      return login(username, password);
    } else if (registerResponse.isError) {
      return ErrorResponse(
        registerResponse.toError().statusCode,
        registerResponse.toError().headers,
        registerResponse.toError().error,
      );
    } else {
      return ExceptionResponse(
        registerResponse.toException().exception,
        registerResponse.toException().stackTrace,
      );
    }
  }

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
