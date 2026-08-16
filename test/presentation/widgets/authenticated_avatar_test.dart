import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/presentation/widgets/authenticated_avatar.dart';

class _SettingsDatasource implements SettingsDatasource {
  @override
  Future<String?> getUserToken() async => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client extends Client {
  final http.Client transport;

  _Client(this.transport) : super(base: 'https://vikunja.example.com');

  @override
  http.Client createClient() => transport;
}

void main() {
  testWidgets('reuses the avatar request across parent rebuilds', (
    tester,
  ) async {
    var requests = 0;
    final client = _Client(
      http_testing.MockClient((_) async {
        requests++;
        return http.Response.bytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..settingsDatasource = _SettingsDatasource();
    late StateSetter rebuild;
    var username = 'alice';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AuthenticatedAvatar(client: client, username: username);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(requests, 1);

    rebuild(() => username = 'bob');
    await tester.pumpAndSettle();
    expect(requests, 2);
  });
}
