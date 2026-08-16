import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/repositories/server_repository.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/login/login_page.dart';

class _CertificateThenFailureServerRepository implements ServerRepository {
  int requests = 0;

  @override
  Future<Response<Server>> getInfo() async {
    requests++;
    if (requests == 1) {
      return ExceptionResponse(
        Exception('TLSV1_ALERT_CERTIFICATE_REQUIRED'),
        StackTrace.empty,
      );
    }
    return ErrorResponse(503, const {}, const {'message': 'unavailable'});
  }
}

/// The optional-cert edge (Envoy `optionalClientCertificate: true`) completes
/// the TLS handshake without a certificate and lets ext_authz deny the certless
/// /api/v1/info with an HTTP 403 — an ErrorResponse, not a TLS exception. The
/// login screen must still offer the certificate picker.
class _ForbiddenThenUnavailableServerRepository implements ServerRepository {
  int requests = 0;

  @override
  Future<Response<Server>> getInfo() async {
    requests++;
    if (requests == 1) {
      return ErrorResponse(403, const {}, const {'error': 'Unauthorized'});
    }
    return ErrorResponse(503, const {}, const {'message': 'unavailable'});
  }
}

class _UnauthorizedThenUnavailableServerRepository implements ServerRepository {
  int requests = 0;

  @override
  Future<Response<Server>> getInfo() async {
    requests++;
    if (requests == 1) {
      return ErrorResponse(401, const {}, const {'error': 'Unauthorized'});
    }
    return ErrorResponse(503, const {}, const {'message': 'unavailable'});
  }
}

class _SuccessfulServerRepository implements ServerRepository {
  @override
  Future<Response<Server>> getInfo() async {
    return SuccessResponse(
      Server(
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        '2.3.0',
      ),
      200,
      const {},
    );
  }
}

class _RecordingOAuthService extends OAuthService {
  bool? usedClientTransport;

  @override
  Future<String> authorize(
    Client client,
    String serverUrl, {
    bool useClientTransport = false,
  }) async {
    usedClientTransport = useClientTransport;
    throw OAuthException(OAuthError.cancelled);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{'sentry-modal-shown': '1'},
    );
  });

  testWidgets('custom server login offers a server-scoped certificate picker', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var chooserCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(
            chooseClientCertificate: () async {
              chooserCalls++;
              return 'selected-alias';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();

    final certificateButton = find.byKey(
      const ValueKey('login-client-certificate'),
    );
    expect(certificateButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(certificateButton).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'one.example.com');
    await tester.pump();
    await tester.tap(certificateButton);
    await tester.pump();

    expect(chooserCalls, 1);
    expect(
      find.text('Client Certificate: selected-alias', skipOffstage: false),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), 'two.example.com');
    await tester.pump();

    expect(find.text('Select Certificate'), findsOneWidget);
    expect(
      find.text('Client Certificate: selected-alias', skipOffstage: false),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ordinary server login keeps the browser OAuth flow', (
    tester,
  ) async {
    final oauthService = _RecordingOAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverRepositoryProvider.overrideWithValue(
            _SuccessfulServerRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(oauthService: oauthService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ordinary.example.com');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(oauthService.usedClientTransport, isFalse);
  });

  testWidgets('certificate login uses the mTLS OAuth transport', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final oauthService = _RecordingOAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverRepositoryProvider.overrideWithValue(
            _SuccessfulServerRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(
            oauthService: oauthService,
            chooseClientCertificate: () async => 'selected-alias',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'mtls.example.com');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-client-certificate')));
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(oauthService.usedClientTransport, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('rejected certificate is not persisted', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final serverRepository = _CertificateThenFailureServerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverRepositoryProvider.overrideWithValue(serverRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(
            chooseClientCertificate: () async => 'rejected-alias',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'one.example.com');
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Client Certificate Required'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Select Certificate'),
      ),
    );
    await tester.pumpAndSettle();

    final settings = SettingsDatasource(const FlutterSecureStorage());
    expect(
      await settings.getClientCertAlias('https://one.example.com'),
      isNull,
    );
    expect(serverRepository.requests, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ext_authz 403 on /info offers the certificate picker', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final serverRepository = _ForbiddenThenUnavailableServerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverRepositoryProvider.overrideWithValue(serverRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(chooseClientCertificate: () async => 'picked-alias'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'mtls.example.com');
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The picker only appears if the 403 was classified as a certificate
    // requirement rather than a generic "cannot reach server".
    expect(find.text('Client Certificate Required'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ext_authz 401 on /info offers the certificate picker', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final serverRepository = _UnauthorizedThenUnavailableServerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverRepositoryProvider.overrideWithValue(serverRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: LoginPage(chooseClientCertificate: () async => 'picked-alias'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Server URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'mtls.example.com');
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Client Certificate Required'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
