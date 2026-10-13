import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAj'
  'CB0C8AAAAASUVORK5CYII=',
);

AvatarImage _image(String contentType, [List<int>? bytes]) => AvatarImage(
  bytes: Uint8List.fromList(bytes ?? _png),
  contentType: contentType,
);

void main() {
  group('AvatarCache', () {
    test('asks once per avatar and size, also while a request runs', () async {
      final requests = <(String, int)>[];
      final cache = AvatarCache((username, size) async {
        requests.add((username, size));
        return _image('image/png');
      });

      final both = await Future.wait([
        cache.load('anna', 64),
        cache.load('anna', 64),
      ]);
      await cache.load('anna', 64);
      await cache.load('anna', 128);

      expect(requests, [('anna', 64), ('anna', 128)]);
      expect(both[0].bytes, isNotNull);
      expect(cache.peek('anna', 64)?.bytes, same(both[0].bytes));
    });

    test('an SVG, an empty answer or a missing avatar is the initials for '
        'the session', () async {
      var now = DateTime(2026, 10, 14, 9);
      final requests = <String>[];
      final cache = AvatarCache((username, size) async {
        requests.add(username);
        return switch (username) {
          'svg' => _image('image/svg+xml', [60, 115]),
          'empty' => _image('image/png', []),
          _ => throw const NotFound(),
        };
      }, now: () => now);

      for (final username in ['svg', 'empty', 'gone']) {
        expect((await cache.load(username, 64)).bytes, isNull);
      }
      now = now.add(const Duration(hours: 5));
      for (final username in ['svg', 'empty', 'gone']) {
        expect((await cache.load(username, 64)).bytes, isNull);
      }

      expect(requests, ['svg', 'empty', 'gone']);
    });

    test('a failure that may pass is the initials for a while, then asked '
        'again', () async {
      var now = DateTime(2026, 10, 14, 9);
      VikunjaFailure? failure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      var requests = 0;
      // Two minutes by default.
      final cache = AvatarCache((username, size) async {
        requests++;
        if (failure case final failure?) throw failure;
        return _image('image/png');
      }, now: () => now);

      expect((await cache.load('anna', 64)).bytes, isNull);
      expect(cache.peek('anna', 64)?.bytes, isNull);
      now = now.add(const Duration(minutes: 1));
      expect((await cache.load('anna', 64)).bytes, isNull);
      expect(requests, 1);

      failure = const ServerFailure(503);
      now = now.add(const Duration(minutes: 1));
      expect(cache.peek('anna', 64), isNull);
      expect((await cache.load('anna', 64)).bytes, isNull);
      expect(requests, 2);

      failure = null;
      now = now.add(const Duration(minutes: 2));
      expect((await cache.load('anna', 64)).bytes, isNotNull);
      now = now.add(const Duration(hours: 1));
      expect(cache.peek('anna', 64)?.bytes, isNotNull);
      expect(requests, 3);
    });

    test('keeps the most recently used avatars', () async {
      final cache = AvatarCache(
        (username, size) async => _image('image/png'),
        capacity: 2,
      );
      await cache.load('a', 32);
      await cache.load('b', 32);
      cache.peek('a', 32);
      await cache.load('c', 32);

      expect(cache.peek('a', 32), isNotNull);
      expect(cache.peek('b', 32), isNull);
      expect(cache.peek('c', 32), isNotNull);
    });

    test('asks for the next size bucket up', () {
      expect(avatarRequestSize(24, 1), 32);
      expect(avatarRequestSize(24, 2), 64);
      expect(avatarRequestSize(24, 3), 128);
      expect(avatarRequestSize(64, 3), 256);
      expect(avatarRequestSize(200, 3), 256);
    });
  });

  group('UserAvatar', () {
    const anna = User(id: 1, username: 'anna', name: 'Anna Example');

    Future<void> pumpAvatar(
      WidgetTester tester, {
      required AvatarFetch fetch,
      String? accountId = 'account',
    }) async {
      final cache = AvatarCache(fetch);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountIdProvider.overrideWithValue(accountId),
            accountAvatarCacheProvider.overrideWith((ref, _) => cache),
          ],
          child: const MaterialApp(
            home: Center(child: UserAvatar(user: anna, radius: 12)),
          ),
        ),
      );
    }

    testWidgets('shows the initials until the image has arrived', (
      tester,
    ) async {
      final response = Completer<AvatarImage>();
      final sizes = <int>[];
      await pumpAvatar(
        tester,
        fetch: (username, size) {
          sizes.add(size);
          return response.future;
        },
      );
      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(find.text('AE'), findsOneWidget);
      // 24 dp at the test view's device pixel ratio of 3.
      expect(sizes, [128]);

      response.complete(_image('image/png'));
      await tester.pump();

      expect(find.byType(InitialsAvatar), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('an SVG avatar or a failure stays the initials', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        fetch: (username, size) async => _image('image/svg+xml', [60]),
      );
      await tester.pump();
      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await pumpAvatar(
        tester,
        fetch: (username, size) async =>
            throw const NetworkFailure(NetworkProblem.unreachable),
      );
      await tester.pump();
      expect(find.byType(InitialsAvatar), findsOneWidget);
    });

    testWidgets('after an offline start the image comes on a later build', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 14, 9);
      var online = false;
      var requests = 0;
      final cache = AvatarCache((username, size) async {
        requests++;
        if (!online) throw const NetworkFailure(NetworkProblem.unreachable);
        return _image('image/png');
      }, now: () => now);
      late StateSetter rebuild;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountIdProvider.overrideWithValue('account'),
            accountAvatarCacheProvider.overrideWith((ref, _) => cache),
          ],
          child: MaterialApp(
            home: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  // A new widget each build, as in a row; a const one is
                  // never rebuilt.
                  // ignore: prefer_const_constructors
                  return UserAvatar(user: anna, radius: 12);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(InitialsAvatar), findsOneWidget);

      online = true;
      rebuild(() {});
      await tester.pump();
      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(requests, 1);

      now = now.add(const Duration(minutes: 5));
      rebuild(() {});
      await tester.pump();
      await tester.pump();

      expect(requests, 2);
      expect(find.byType(InitialsAvatar), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('signed out, only the initials', (tester) async {
      var requests = 0;
      await pumpAvatar(
        tester,
        accountId: null,
        fetch: (username, size) async {
          requests++;
          return _image('image/png');
        },
      );
      await tester.pump();

      expect(find.byType(InitialsAvatar), findsOneWidget);
      expect(requests, 0);
    });

    testWidgets('adds nothing to the semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpAvatar(
        tester,
        fetch: (username, size) async => _image('image/png'),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      semantics.dispose();
    });
  });
}
