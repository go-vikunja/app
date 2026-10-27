import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

/// Shows a web page in the system browser sheet until it redirects to the
/// callback scheme.
abstract interface class WebAuthenticator {
  /// The URL the browser was redirected to, or null when the user closed the
  /// sheet.
  Future<Uri?> authenticate(Uri url, {required String callbackUrlScheme});
}

enum WebAuthenticationProblem { noBrowser, failed }

final class WebAuthenticationFailed implements Exception {
  const new(this.problem, {this.platformCode});

  final WebAuthenticationProblem problem;
  final String? platformCode;

  @override
  String toString() => 'WebAuthenticationFailed($problem, $platformCode)';
}

/// ASWebAuthenticationSession on iOS, Custom Tabs on Android; leaving the
/// app for it does not lock the app.
final class FlutterWebAuthenticator implements WebAuthenticator {
  const new({this.excursions});

  final AppExcursions? excursions;

  @override
  Future<Uri?> authenticate(
    Uri url, {
    required String callbackUrlScheme,
  }) async {
    final String callback;
    try {
      // Ephemeral, so a web login in the system browser is never redeemed
      // silently: Vikunja has no consent screen and sends no `iss`, so a code
      // from another server would be indistinguishable.
      Future<String> open() => FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true),
      );
      callback = await (excursions?.roundTrip(open) ?? open());
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') return null;
      // The message and details can echo the URL, so only the code is kept.
      throw WebAuthenticationFailed(
        error.code == 'NO_BROWSER'
            ? WebAuthenticationProblem.noBrowser
            : WebAuthenticationProblem.failed,
        platformCode: error.code,
      );
    }
    return Uri.tryParse(callback) ?? Uri();
  }
}
