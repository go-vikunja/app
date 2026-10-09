import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_web_auth_2');
  final url = Uri.parse(
    'https://tasks.example.org/oauth/authorize?response_type=code&state=s',
  );
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) answer;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return answer(call);
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<Uri?> authenticate() => const FlutterWebAuthenticator().authenticate(
    url,
    callbackUrlScheme: oauthCallbackScheme,
  );

  test('opens an ephemeral session and returns the callback', () async {
    answer = (_) async =>
        '$oauthCallbackScheme://oauth/callback?code=c&state=s';

    final callback = await authenticate();

    expect(callback?.queryParameters, {'code': 'c', 'state': 's'});
    final call = calls.singleWhere((call) => call.method == 'authenticate');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['url'], url.toString());
    expect(arguments['callbackUrlScheme'], oauthCallbackScheme);
    expect(
      (arguments['options']! as Map<Object?, Object?>)['preferEphemeral'],
      isTrue,
    );
  });

  test('closing the sheet returns null', () async {
    answer = (_) async => throw PlatformException(code: 'CANCELED');

    expect(await authenticate(), isNull);
  });

  test('no browser is reported as such', () async {
    answer = (_) async => throw PlatformException(
      code: 'NO_BROWSER',
      message: 'No valid browser available for authentication.',
    );

    await expectLater(
      authenticate(),
      throwsA(
        isA<WebAuthenticationFailed>()
            .having(
              (e) => e.problem,
              'problem',
              WebAuthenticationProblem.noBrowser,
            )
            .having((e) => e.platformCode, 'platformCode', 'NO_BROWSER'),
      ),
    );
  });

  test('other platform errors keep only their code', () async {
    answer = (_) async => throw PlatformException(
      code: 'SECURITY_EXCEPTION',
      message: 'details mentioning $url',
    );

    await expectLater(
      authenticate(),
      throwsA(
        isA<WebAuthenticationFailed>()
            .having(
              (e) => e.problem,
              'problem',
              WebAuthenticationProblem.failed,
            )
            .having((e) => '$e', 'toString', isNot(contains('example.org'))),
      ),
    );
  });
}
