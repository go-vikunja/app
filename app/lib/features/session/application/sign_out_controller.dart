import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';

part 'sign_out_controller.g.dart';

/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.
@Riverpod(keepAlive: true)
class SignOutController extends _$SignOutController {
  @override
  bool build() => false;

  /// Navigation away follows from the account registry.
  Future<void> signOut(String accountId) async {
    if (state) return;
    state = true;
    try {
      await ref.read(signOutProvider).call(accountId);
    } finally {
      state = false;
    }
  }
}
