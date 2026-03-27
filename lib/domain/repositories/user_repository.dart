import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/user.dart';

abstract class UserRepository {
  Future<Response<User>> getCurrentUser();

  Future<Response<UserSettings>> setCurrentUserSettings(
    UserSettings userSettings,
  );
}
