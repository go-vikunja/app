import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

final class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 500);
  }

  @override
  void close({bool force = false}) {}
}

// The native adapters bound a request by its connect and receive timeouts
// together, so a background token request must count both against the time
// left before the run's container goes (D59).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('${platform.name}: token requests of a background run connect '
        'within the shorter timeout and wait only as long as the run '
        'leaves', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          ...backgroundTokenOverrides,
          clientIdentityProvider.overrideWithValue(
            const ClientIdentity(
              appVersion: '1.0.0',
              buildNumber: '1',
              platform: 'android',
              osVersion: '15',
            ),
          ),
          preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
        ],
      );
      addTearDown(container.dispose);
      final adapter = _RecordingAdapter();
      final authDio = container.read(authDioProvider)
        ..httpClientAdapter = adapter;
      final cutoff = container.read(refreshCutoffProvider);
      final gateway = container.read(tokenGatewayProvider);

      expect(authDio.options.connectTimeout, backgroundConnectTimeout);
      expect(
        backgroundConnectTimeout,
        lessThanOrEqualTo(defaultConnectTimeout),
      );

      const headroom = Duration(seconds: 1);
      cutoff.answerWithin(
        backgroundConnectTimeout + backgroundTokenTimeout + headroom,
      );
      expect(cutoff.allowsRefresh, isTrue);
      await expectLater(
        gateway.refresh(fullServer270(), 'refresh'),
        throwsA(isA<VikunjaFailure>()),
      );
      cutoff.answerWithin(const Duration(minutes: 5));
      await expectLater(
        gateway.refresh(fullServer270(), 'refresh'),
        throwsA(isA<VikunjaFailure>()),
      );

      final [first, second] = adapter.requests;
      expect(
        first.receiveTimeout!.inMilliseconds,
        closeTo((backgroundTokenTimeout + headroom).inMilliseconds, 500),
      );
      expect(second.receiveTimeout, const Duration(seconds: 60));
    });
  }
}
