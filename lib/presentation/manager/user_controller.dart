import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/user.dart';

part 'user_controller.g.dart';

@riverpod
class UserController extends _$UserController {
  @override
  Future<User> build() async {
    return ref.read(userRepositoryProvider).getCurrentUser();
  }

  Future<void> setCurrentUserSettings(UserSettings userSettings) async {
    var settings = await ref
        .read(userRepositoryProvider)
        .setCurrentUserSettings(userSettings);

    //TODO better way?
    state.value?.settings = settings;
    state = AsyncData(state.value!);
  }
}
