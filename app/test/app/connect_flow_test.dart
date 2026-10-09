import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

// Exercises the real DioServerConnector behind the providers; only the HTTP
// transport is faked, answering with /info bodies captured from real servers.

const _identity = ClientIdentity(
  appVersion: '0.1.0',
  buildNumber: '1',
  platform: 'android',
  osVersion: '15',
);

String _fixture(String name) =>
    File('../packages/vikunja_api/test/fixtures/$name').readAsStringSync();

final class _RoutingAdapter implements HttpClientAdapter {
  new(this.routes);

  final Map<String, (int, String)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes[options.uri.toString()];
    if (route == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
        error: const SocketException('Connection refused'),
      );
    }
    final (status, body) = route;
    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_RoutingAdapter> _pumpApp(
  WidgetTester tester,
  Map<String, (int, String)> routes,
) async {
  final adapter = _RoutingAdapter(routes);
  final dio = createDio(
    userAgent: _identity.userAgent,
    httpClientAdapter: adapter,
    logRequests: false,
  );
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        externalLinkOpenerProvider.overrideWithValue(FakeExternalLinkOpener()),
        ...AuthFakes().overrides,
      ],
      child: const VikunjaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

Future<void> _connect(WidgetTester tester, String address) async {
  await tester.enterText(find.byType(TextFormField), address);
  await tester.tap(find.widgetWithText(FilledButton, en.connectContinue));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 2.7 server over https opens its overview', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    final adapter = await _pumpApp(tester, {
      'https://vikunja.example.com/api/v2/info': (
        200,
        _fixture('info_v2_2.7.0.json'),
      ),
      'https://vikunja.example.com/api/v1/info': (
        200,
        _fixture('info_v1_2.7.0.json'),
      ),
    });

    await _connect(tester, 'vikunja.example.com');

    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(find.bySemanticsLabel('vikunja.example.com'), findsOneWidget);
    for (final text in [
      en.overviewVikunjaVersion('2.7.0'),
      en.overviewApiBadge('v2'),
      en.overviewApiBadge('v1'),
      en.tierFullTitle,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text(en.overviewInsecureBadge), findsNothing);
    expect(
      adapter.requests.map((request) => request.headers['User-Agent']).toSet(),
      {'Taskuna/0.1.0+1 (android 15)'},
    );
  });

  testWidgets('a 1.0 server over http needs consent and is unsupported', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    await _pumpApp(tester, {
      'http://old.example.com/api/v2/info': (
        404,
        _fixture('v2_info_404_2.3.0.json'),
      ),
      'http://old.example.com/api/v1/info': (
        200,
        _fixture('info_v1_1.0.0.json'),
      ),
    });

    await _connect(tester, 'old.example.com');

    expect(find.text(en.insecureDialogTitle), findsOneWidget);
    await tester.tap(find.text(en.insecureDialogContinue));
    await tester.pumpAndSettle();

    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(find.text(en.unsupportedTitle), findsOneWidget);
    expect(find.text(en.overviewInsecureBadge), findsOneWidget);
    expect(find.text(en.continueToSignIn), findsNothing);
    expect(
      find.widgetWithText(FilledButton, en.useDifferentServer),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable address shows the error card', (tester) async {
    await _pumpApp(tester, {});

    await _connect(tester, 'nope.invalid');

    expect(find.byType(ConnectionErrorCard), findsOneWidget);
    expect(find.text(en.failureUnreachableTitle), findsOneWidget);
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });
}
